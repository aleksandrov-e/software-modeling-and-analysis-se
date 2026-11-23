/* =====================================================================
   Курсова работа – eBay | ф.н. 2401321025
   Файл 02: Функции, съхранени процедури, тригери и изгледи
   Изпълнява се СЛЕД 01_create_database.sql и ПРЕДИ 03_seed_data.sql
   (тригерите поддържат CurrentPrice, FeedbackScore и TotalAmount
    актуални и при зареждането на тестовите данни).
   ===================================================================== */

USE eBayDB;
GO

/* =====================================================================
   ФУНКЦИИ
   ===================================================================== */

/* ---------------------------------------------------------------------
   fn_GetBidIncrement – минимална стъпка за наддаване по таблицата на eBay
   --------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION dbo.fn_GetBidIncrement (@Price DECIMAL(10,2))
RETURNS DECIMAL(10,2)
AS
BEGIN
    RETURN CASE
        WHEN @Price <    1.00 THEN   0.05
        WHEN @Price <    5.00 THEN   0.25
        WHEN @Price <   25.00 THEN   0.50
        WHEN @Price <  100.00 THEN   1.00
        WHEN @Price <  250.00 THEN   2.50
        WHEN @Price <  500.00 THEN   5.00
        WHEN @Price < 1000.00 THEN  10.00
        WHEN @Price < 2500.00 THEN  25.00
        WHEN @Price < 5000.00 THEN  50.00
        ELSE 100.00
    END;
END;
GO

/* ---------------------------------------------------------------------
   fn_GetMinNextBid – минималната валидна следваща оферта за обява
   --------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION dbo.fn_GetMinNextBid (@ListingID INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @Result DECIMAL(10,2);

    SELECT @Result =
        CASE WHEN EXISTS (SELECT 1 FROM dbo.Bids b WHERE b.ListingID = l.ListingID)
             THEN l.CurrentPrice + dbo.fn_GetBidIncrement(l.CurrentPrice)
             ELSE l.StartPrice
        END
    FROM dbo.Listings l
    WHERE l.ListingID = @ListingID;

    RETURN @Result;
END;
GO

/* ---------------------------------------------------------------------
   fn_GetSellerPositivePercent – % положителни оценки за продавач
   (както „Positive feedback %“ в eBay; неутралните не се броят)
   --------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION dbo.fn_GetSellerPositivePercent (@SellerID INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @Positive INT, @Negative INT;

    SELECT @Positive = SUM(CASE WHEN Rating =  1 THEN 1 ELSE 0 END),
           @Negative = SUM(CASE WHEN Rating = -1 THEN 1 ELSE 0 END)
    FROM dbo.Feedback
    WHERE ToUserID = @SellerID;

    IF ISNULL(@Positive, 0) + ISNULL(@Negative, 0) = 0
        RETURN NULL;

    RETURN CAST(100.0 * @Positive / (@Positive + @Negative) AS DECIMAL(5,2));
END;
GO

/* ---------------------------------------------------------------------
   fn_GetActiveListingsByCategory – таблична функция: активните обяви
   в дадена категория И във всички нейни подкатегории (рекурсивен CTE)
   --------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION dbo.fn_GetActiveListingsByCategory (@CategoryID INT)
RETURNS TABLE
AS
RETURN
(
    WITH CategoryTree AS
    (
        SELECT CategoryID FROM dbo.Categories WHERE CategoryID = @CategoryID
        UNION ALL
        SELECT c.CategoryID
        FROM dbo.Categories c
        INNER JOIN CategoryTree t ON c.ParentCategoryID = t.CategoryID
    )
    SELECT l.ListingID, l.Title, c.Name AS CategoryName, u.Username AS Seller,
           l.ListingFormat, l.ItemCondition, l.CurrentPrice, l.BuyItNowPrice,
           l.ShippingCost, l.EndDate,
           (SELECT COUNT(*) FROM dbo.Bids b WHERE b.ListingID = l.ListingID) AS BidCount
    FROM dbo.Listings l
    INNER JOIN CategoryTree t ON t.CategoryID = l.CategoryID
    INNER JOIN dbo.Categories c ON c.CategoryID = l.CategoryID
    INNER JOIN dbo.Users u ON u.UserID = l.SellerID
    WHERE l.Status = N'Active'
);
GO

/* =====================================================================
   ТРИГЕРИ
   ===================================================================== */

/* ---------------------------------------------------------------------
   trg_Bids_AfterInsert
   - забранява наддаване по собствена обява и по обява тип „Купи сега“
   - обновява Listings.CurrentPrice с най-високата оферта
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_Bids_AfterInsert
ON dbo.Bids
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1
               FROM inserted i
               INNER JOIN dbo.Listings l ON l.ListingID = i.ListingID
               WHERE l.SellerID = i.BidderID OR l.ListingFormat <> N'Auction')
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50001, N'Невалидна оферта: продавачът не може да наддава по своя обява, а наддаване е позволено само при търг.', 1;
    END;

    UPDATE l
    SET l.CurrentPrice = x.MaxBid
    FROM dbo.Listings l
    INNER JOIN (SELECT b.ListingID, MAX(b.BidAmount) AS MaxBid
                FROM dbo.Bids b
                WHERE b.ListingID IN (SELECT ListingID FROM inserted)
                GROUP BY b.ListingID) x ON x.ListingID = l.ListingID
    WHERE x.MaxBid > l.CurrentPrice;
END;
GO

/* ---------------------------------------------------------------------
   trg_Feedback_UpdateScore – поддържа Users.FeedbackScore
   (сбор от оценките: +1 / 0 / -1) при INSERT, UPDATE и DELETE
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_Feedback_UpdateScore
ON dbo.Feedback
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE u
    SET u.FeedbackScore = u.FeedbackScore + d.Delta
    FROM dbo.Users u
    INNER JOIN (SELECT ToUserID, SUM(Rating) AS Delta
                FROM (SELECT ToUserID, CAST(Rating AS INT) AS Rating FROM inserted
                      UNION ALL
                      SELECT ToUserID, -CAST(Rating AS INT) FROM deleted) t
                GROUP BY ToUserID) d ON d.ToUserID = u.UserID
    WHERE d.Delta <> 0;
END;
GO

/* ---------------------------------------------------------------------
   trg_OrderItems_RecalcTotal – преизчислява Orders.TotalAmount
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_OrderItems_RecalcTotal
ON dbo.OrderItems
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE o
    SET o.TotalAmount = ISNULL((SELECT SUM(oi.Quantity * oi.UnitPrice + oi.ShippingCost)
                                FROM dbo.OrderItems oi
                                WHERE oi.OrderID = o.OrderID), 0)
    FROM dbo.Orders o
    WHERE o.OrderID IN (SELECT OrderID FROM inserted
                        UNION
                        SELECT OrderID FROM deleted);
END;
GO

/* ---------------------------------------------------------------------
   trg_Shipments_SyncOrderStatus – синхронизира статуса на поръчката
   с този на пратката
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_Shipments_SyncOrderStatus
ON dbo.Shipments
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE o
    SET o.Status = CASE i.ShippingStatus
                       WHEN N'Delivered' THEN N'Delivered'
                       WHEN N'Returned'  THEN N'Returned'
                       ELSE CASE WHEN o.Status IN (N'Pending', N'Paid') THEN N'Shipped' ELSE o.Status END
                   END
    FROM dbo.Orders o
    INNER JOIN inserted i ON i.OrderID = o.OrderID;
END;
GO

/* ---------------------------------------------------------------------
   trg_Listings_SoftDelete (INSTEAD OF DELETE)
   Обява с наддавания или поръчки не се изтрива физически, а се
   маркира като „Cancelled“; останалите се изтриват заедно с Watchlist.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_Listings_SoftDelete
ON dbo.Listings
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE l
    SET l.Status = N'Cancelled'
    FROM dbo.Listings l
    INNER JOIN deleted d ON d.ListingID = l.ListingID
    WHERE EXISTS (SELECT 1 FROM dbo.Bids b WHERE b.ListingID = d.ListingID)
       OR EXISTS (SELECT 1 FROM dbo.OrderItems oi WHERE oi.ListingID = d.ListingID);

    DELETE w
    FROM dbo.Watchlist w
    INNER JOIN deleted d ON d.ListingID = w.ListingID
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Bids b WHERE b.ListingID = d.ListingID)
      AND NOT EXISTS (SELECT 1 FROM dbo.OrderItems oi WHERE oi.ListingID = d.ListingID);

    DELETE l
    FROM dbo.Listings l
    INNER JOIN deleted d ON d.ListingID = l.ListingID
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Bids b WHERE b.ListingID = d.ListingID)
      AND NOT EXISTS (SELECT 1 FROM dbo.OrderItems oi WHERE oi.ListingID = d.ListingID);
END;
GO

/* =====================================================================
   СЪХРАНЕНИ ПРОЦЕДУРИ
   ===================================================================== */

/* ---------------------------------------------------------------------
   sp_PlaceBid – наддаване по търг с пълна валидация
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_PlaceBid
    @ListingID INT,
    @BidderID  INT,
    @Amount    DECIMAL(10,2),
    @BidID     INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Status NVARCHAR(10), @Format NVARCHAR(10), @SellerID INT, @EndDate DATETIME2(0);

        SELECT @Status = Status, @Format = ListingFormat, @SellerID = SellerID, @EndDate = EndDate
        FROM dbo.Listings WITH (UPDLOCK, HOLDLOCK)
        WHERE ListingID = @ListingID;

        IF @Status IS NULL
            THROW 50010, N'Обявата не съществува.', 1;
        IF @Format <> N'Auction'
            THROW 50011, N'По тази обява не може да се наддава (не е търг).', 1;
        IF @Status <> N'Active' OR @EndDate <= SYSDATETIME()
            THROW 50012, N'Търгът е приключил.', 1;
        IF @SellerID = @BidderID
            THROW 50013, N'Продавачът не може да наддава по собствената си обява.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserID = @BidderID AND IsActive = 1)
            THROW 50014, N'Потребителят не съществува или е деактивиран.', 1;

        DECLARE @MinBid DECIMAL(10,2) = dbo.fn_GetMinNextBid(@ListingID);
        IF @Amount < @MinBid
        BEGIN
            DECLARE @Msg NVARCHAR(200) = CONCAT(N'Офертата трябва да е поне ', @MinBid, N'.');
            THROW 50015, @Msg, 1;
        END;

        INSERT INTO dbo.Bids (ListingID, BidderID, BidAmount)
        VALUES (@ListingID, @BidderID, @Amount);

        SET @BidID = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ---------------------------------------------------------------------
   sp_BuyItNow – покупка „Купи сега“: създава поръчка, ред и плащане
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_BuyItNow
    @BuyerID         INT,
    @ListingID       INT,
    @Quantity        INT = 1,
    @PaymentMethod   NVARCHAR(20) = N'PayPal',
    @ShippingAddress NVARCHAR(200),
    @OrderID         INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @SellerID INT, @Price DECIMAL(10,2), @Shipping DECIMAL(8,2),
                @Available INT, @Status NVARCHAR(10), @EndDate DATETIME2(0);

        SELECT @SellerID  = SellerID,
               @Price     = COALESCE(BuyItNowPrice, CurrentPrice),
               @Shipping  = ShippingCost,
               @Available = Quantity - QuantitySold,
               @Status    = Status,
               @EndDate   = EndDate
        FROM dbo.Listings WITH (UPDLOCK, HOLDLOCK)
        WHERE ListingID = @ListingID
          AND (ListingFormat = N'BuyItNow' OR BuyItNowPrice IS NOT NULL);

        IF @SellerID IS NULL
            THROW 50020, N'Обявата не съществува или няма опция „Купи сега“.', 1;
        IF @Status <> N'Active' OR @EndDate <= SYSDATETIME()
            THROW 50021, N'Обявата не е активна.', 1;
        IF @SellerID = @BuyerID
            THROW 50022, N'Не можете да купите собствена обява.', 1;
        IF @Quantity < 1 OR @Quantity > @Available
            THROW 50023, N'Няма достатъчна наличност.', 1;

        DECLARE @City NVARCHAR(60), @Country NVARCHAR(60);
        SELECT @City = City, @Country = Country FROM dbo.Users WHERE UserID = @BuyerID;

        INSERT INTO dbo.Orders (BuyerID, Status, ShippingAddress, ShippingCity, ShippingCountry)
        VALUES (@BuyerID, N'Paid', @ShippingAddress, @City, @Country);
        SET @OrderID = SCOPE_IDENTITY();

        INSERT INTO dbo.OrderItems (OrderID, ListingID, Quantity, UnitPrice, ShippingCost)
        VALUES (@OrderID, @ListingID, @Quantity, @Price, @Shipping);   -- тригерът изчислява TotalAmount

        INSERT INTO dbo.Payments (OrderID, PaymentMethod, Amount, Status, TransactionRef)
        SELECT @OrderID, @PaymentMethod, TotalAmount, N'Completed',
               CONCAT(N'TX-', UPPER(LEFT(REPLACE(CONVERT(NVARCHAR(36), NEWID()), N'-', N''), 16)))
        FROM dbo.Orders WHERE OrderID = @OrderID;

        -- Купи сега при търг: търгът приключва веднага
        UPDATE dbo.Listings
        SET QuantitySold = QuantitySold + @Quantity,
            CurrentPrice = CASE WHEN ListingFormat = N'Auction' THEN @Price ELSE CurrentPrice END,
            Status       = CASE WHEN QuantitySold + @Quantity >= Quantity THEN N'Sold' ELSE Status END
        WHERE ListingID = @ListingID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ---------------------------------------------------------------------
   sp_CloseEndedAuctions – приключва изтеклите търгове.
   С оферти -> „Sold“ + поръчка за печелившия; без оферти -> „Ended“.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_CloseEndedAuctions
    @AsOf DATETIME2(0) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @AsOf = ISNULL(@AsOf, SYSDATETIME());

    DECLARE @Winners TABLE (ListingID INT PRIMARY KEY, WinnerID INT, FinalPrice DECIMAL(10,2),
                            ShippingCost DECIMAL(8,2), EndDate DATETIME2(0));

    BEGIN TRANSACTION;

    INSERT INTO @Winners (ListingID, WinnerID, FinalPrice, ShippingCost, EndDate)
    SELECT l.ListingID, w.BidderID, w.BidAmount, l.ShippingCost, l.EndDate
    FROM dbo.Listings l
    CROSS APPLY (SELECT TOP (1) b.BidderID, b.BidAmount
                 FROM dbo.Bids b
                 WHERE b.ListingID = l.ListingID
                 ORDER BY b.BidAmount DESC, b.BidTime ASC) w
    WHERE l.ListingFormat = N'Auction' AND l.Status = N'Active' AND l.EndDate <= @AsOf;

    DECLARE @ListingID INT, @WinnerID INT, @Price DECIMAL(10,2), @Ship DECIMAL(8,2),
            @End DATETIME2(0), @NewOrderID INT;

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT ListingID, WinnerID, FinalPrice, ShippingCost, EndDate FROM @Winners;
    OPEN cur;
    FETCH NEXT FROM cur INTO @ListingID, @WinnerID, @Price, @Ship, @End;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        INSERT INTO dbo.Orders (BuyerID, OrderDate, Status, ShippingAddress, ShippingCity, ShippingCountry)
        SELECT UserID, @End, N'Pending', N'(адрес от профила)', City, Country
        FROM dbo.Users WHERE UserID = @WinnerID;
        SET @NewOrderID = SCOPE_IDENTITY();

        INSERT INTO dbo.OrderItems (OrderID, ListingID, Quantity, UnitPrice, ShippingCost)
        VALUES (@NewOrderID, @ListingID, 1, @Price, @Ship);

        FETCH NEXT FROM cur INTO @ListingID, @WinnerID, @Price, @Ship, @End;
    END;
    CLOSE cur;
    DEALLOCATE cur;

    UPDATE l SET Status = N'Sold', QuantitySold = 1
    FROM dbo.Listings l INNER JOIN @Winners w ON w.ListingID = l.ListingID;

    UPDATE dbo.Listings
    SET Status = N'Ended'
    WHERE Status = N'Active' AND EndDate <= @AsOf;   -- търгове без оферти и изтекли „Купи сега“

    COMMIT TRANSACTION;

    SELECT (SELECT COUNT(*) FROM @Winners) AS AuctionsSold;
END;
GO

/* ---------------------------------------------------------------------
   sp_ShipOrder – регистрира изпращане на платена поръчка
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_ShipOrder
    @OrderID        INT,
    @Carrier        NVARCHAR(30),
    @TrackingNumber NVARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Orders WHERE OrderID = @OrderID AND Status = N'Paid')
        THROW 50030, N'Може да се изпрати само платена поръчка.', 1;

    INSERT INTO dbo.Shipments (OrderID, Carrier, TrackingNumber, ShippedDate)
    VALUES (@OrderID, @Carrier, @TrackingNumber, SYSDATETIME());   -- тригерът сменя статуса на „Shipped“
END;
GO

/* ---------------------------------------------------------------------
   sp_LeaveFeedback – оценка след доставена поръчка.
   Получателят се определя автоматично (купувач -> продавач и обратно).
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_LeaveFeedback
    @OrderItemID INT,
    @FromUserID  INT,
    @Rating      SMALLINT,
    @Comment     NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @BuyerID INT, @SellerID INT, @OrderStatus NVARCHAR(10);

    SELECT @BuyerID = o.BuyerID, @SellerID = l.SellerID, @OrderStatus = o.Status
    FROM dbo.OrderItems oi
    INNER JOIN dbo.Orders o   ON o.OrderID = oi.OrderID
    INNER JOIN dbo.Listings l ON l.ListingID = oi.ListingID
    WHERE oi.OrderItemID = @OrderItemID;

    IF @BuyerID IS NULL
        THROW 50040, N'Редът от поръчката не съществува.', 1;
    IF @FromUserID NOT IN (@BuyerID, @SellerID)
        THROW 50041, N'Само участниците в сделката могат да оставят оценка.', 1;
    IF @OrderStatus NOT IN (N'Delivered', N'Returned')
        THROW 50042, N'Оценка може да се остави само след доставка.', 1;

    INSERT INTO dbo.Feedback (OrderItemID, FromUserID, ToUserID, Rating, Comment)
    VALUES (@OrderItemID, @FromUserID,
            CASE WHEN @FromUserID = @BuyerID THEN @SellerID ELSE @BuyerID END,
            @Rating, @Comment);                                  -- тригерът обновява FeedbackScore
END;
GO

/* ---------------------------------------------------------------------
   sp_GetSellerReport – отчет за продавач за период (3 резултатни набора)
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_GetSellerReport
    @SellerID INT,
    @From     DATE = '2000-01-01',
    @To       DATE = '2100-01-01'
AS
BEGIN
    SET NOCOUNT ON;

    -- 1) Обобщение
    SELECT u.Username, u.FeedbackScore,
           dbo.fn_GetSellerPositivePercent(u.UserID) AS PositivePercent,
           (SELECT COUNT(*) FROM dbo.Listings WHERE SellerID = u.UserID) AS TotalListings,
           ISNULL(s.Revenue, 0) AS Revenue,
           ISNULL(s.Orders, 0)  AS Orders
    FROM dbo.Users u
    OUTER APPLY (SELECT SUM(oi.Quantity * oi.UnitPrice) AS Revenue,
                        COUNT(DISTINCT o.OrderID)       AS Orders
                 FROM dbo.OrderItems oi
                 INNER JOIN dbo.Orders o   ON o.OrderID = oi.OrderID
                 INNER JOIN dbo.Listings l ON l.ListingID = oi.ListingID
                 WHERE l.SellerID = u.UserID
                   AND o.Status NOT IN (N'Cancelled', N'Returned')
                   AND o.OrderDate >= @From AND o.OrderDate < DATEADD(DAY, 1, @To)) s
    WHERE u.UserID = @SellerID;

    -- 2) Приходи по категория
    SELECT c.Name AS Category, SUM(oi.Quantity) AS ItemsSold, SUM(oi.Quantity * oi.UnitPrice) AS Revenue
    FROM dbo.OrderItems oi
    INNER JOIN dbo.Orders o     ON o.OrderID = oi.OrderID
    INNER JOIN dbo.Listings l   ON l.ListingID = oi.ListingID
    INNER JOIN dbo.Categories c ON c.CategoryID = l.CategoryID
    WHERE l.SellerID = @SellerID
      AND o.Status NOT IN (N'Cancelled', N'Returned')
      AND o.OrderDate >= @From AND o.OrderDate < DATEADD(DAY, 1, @To)
    GROUP BY c.Name
    ORDER BY Revenue DESC;

    -- 3) Последни оценки
    SELECT TOP (10) f.CreatedAt, fu.Username AS FromUser, f.Rating, f.Comment
    FROM dbo.Feedback f
    INNER JOIN dbo.Users fu ON fu.UserID = f.FromUserID
    WHERE f.ToUserID = @SellerID
    ORDER BY f.CreatedAt DESC;
END;
GO

/* =====================================================================
   ИЗГЛЕДИ (допълнение)
   ===================================================================== */

CREATE OR ALTER VIEW dbo.vw_ActiveListings
AS
SELECT l.ListingID, l.Title, c.Name AS Category, pc.Name AS ParentCategory,
       u.Username AS Seller, u.FeedbackScore AS SellerScore,
       l.ListingFormat, l.ItemCondition, l.CurrentPrice, l.BuyItNowPrice, l.ShippingCost,
       l.Quantity - l.QuantitySold AS Available, l.EndDate,
       (SELECT COUNT(*) FROM dbo.Bids b WHERE b.ListingID = l.ListingID) AS BidCount,
       (SELECT COUNT(*) FROM dbo.Watchlist w WHERE w.ListingID = l.ListingID) AS Watchers
FROM dbo.Listings l
INNER JOIN dbo.Categories c ON c.CategoryID = l.CategoryID
LEFT  JOIN dbo.Categories pc ON pc.CategoryID = c.ParentCategoryID
INNER JOIN dbo.Users u ON u.UserID = l.SellerID
WHERE l.Status = N'Active';
GO

CREATE OR ALTER VIEW dbo.vw_SellerPerformance
AS
SELECT u.UserID, u.Username, u.Country, u.FeedbackScore,
       dbo.fn_GetSellerPositivePercent(u.UserID) AS PositivePercent,
       COUNT(DISTINCT l.ListingID) AS Listings,
       COUNT(DISTINCT oi.OrderItemID) AS ItemsSold,
       ISNULL(SUM(oi.Quantity * oi.UnitPrice), 0) AS Revenue
FROM dbo.Users u
INNER JOIN dbo.Listings l   ON l.SellerID = u.UserID
LEFT  JOIN dbo.OrderItems oi ON oi.ListingID = l.ListingID
GROUP BY u.UserID, u.Username, u.Country, u.FeedbackScore;
GO

CREATE OR ALTER VIEW dbo.vw_MonthlySales
AS
SELECT YEAR(o.OrderDate) AS [Year], MONTH(o.OrderDate) AS [Month],
       COUNT(DISTINCT o.OrderID) AS Orders,
       SUM(oi.Quantity) AS Items,
       SUM(oi.Quantity * oi.UnitPrice) AS Revenue
FROM dbo.Orders o
INNER JOIN dbo.OrderItems oi ON oi.OrderID = o.OrderID
WHERE o.Status NOT IN (N'Cancelled', N'Returned')
GROUP BY YEAR(o.OrderDate), MONTH(o.OrderDate);
GO

PRINT N'Функциите, процедурите, тригерите и изгледите са създадени.';
GO
