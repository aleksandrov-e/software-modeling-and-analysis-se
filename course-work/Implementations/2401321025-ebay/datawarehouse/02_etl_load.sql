/* =====================================================================
   Курсова работа – eBay | ф.н. 2401321025
   ETL: зареждане на eBayDW от OLTP базата eBayDB
   Пълно презареждане (full reload) чрез процедурата dbo.sp_LoadDW.
   Изпълнява се след 01_create_dw.sql; двете бази са на един сървър.
   ===================================================================== */

USE eBayDW;
GO

/* Дневник на ETL зарежданията (допълнение) */
IF OBJECT_ID(N'dbo.EtlLog', N'U') IS NULL
CREATE TABLE dbo.EtlLog
(
    LoadID          INT IDENTITY(1,1) PRIMARY KEY,
    StartedAt       DATETIME2(0) NOT NULL,
    FinishedAt      DATETIME2(0) NULL,
    SalesRows       INT NULL,
    BidRows         INT NULL,
    FeedbackRows    INT NULL,
    ListingRows     INT NULL
);
GO

CREATE OR ALTER PROCEDURE dbo.sp_LoadDW
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LoadID INT;
    INSERT INTO dbo.EtlLog (StartedAt) VALUES (SYSDATETIME());
    SET @LoadID = SCOPE_IDENTITY();

    BEGIN TRANSACTION;

    /* ---------- 0. Изчистване (фактите първо заради FK) ---------- */
    TRUNCATE TABLE dbo.FactSales;
    TRUNCATE TABLE dbo.FactBids;
    TRUNCATE TABLE dbo.FactFeedback;
    TRUNCATE TABLE dbo.FactListings;
    DELETE FROM dbo.DimUser;
    DELETE FROM dbo.DimCategory;
    DELETE FROM dbo.DimListing;
    DELETE FROM dbo.DimLocation;
    DELETE FROM dbo.DimPaymentMethod;
    DELETE FROM dbo.DimCarrier;
    DELETE FROM dbo.DimOrderStatus;
    DELETE FROM dbo.DimDate;

    /* ---------- 1. DimDate: 01.01.2023 – 31.12.(текуща година + 2) ---------- */
    DECLARE @d DATE = '2023-01-01', @last DATE = DATEFROMPARTS(YEAR(SYSDATETIME()) + 2, 12, 31), @dow TINYINT;
    WHILE @d <= @last
    BEGIN
        SET @dow = (DATEPART(WEEKDAY, @d) + @@DATEFIRST - 2) % 7 + 1;   -- 1 = понеделник
        INSERT INTO dbo.DimDate (DateKey, FullDate, DayOfMonth, DayOfWeek, DayName, IsWeekend, WeekOfYear,
                                 MonthNumber, MonthName, Quarter, QuarterName, [Year], YearMonth)
        VALUES (YEAR(@d) * 10000 + MONTH(@d) * 100 + DAY(@d), @d, DAY(@d), @dow,
                CHOOSE(@dow, N'Monday', N'Tuesday', N'Wednesday', N'Thursday', N'Friday', N'Saturday', N'Sunday'),
                CASE WHEN @dow >= 6 THEN 1 ELSE 0 END,
                DATEPART(ISO_WEEK, @d), MONTH(@d),
                CHOOSE(MONTH(@d), N'January', N'February', N'March', N'April', N'May', N'June', N'July',
                       N'August', N'September', N'October', N'November', N'December'),
                DATEPART(QUARTER, @d), CONCAT('Q', DATEPART(QUARTER, @d)), YEAR(@d),
                CONVERT(CHAR(7), @d, 126));
        SET @d = DATEADD(DAY, 1, @d);
    END;

    /* ---------- 2. DimLocation: адреси на потребители и на доставки ---------- */
    INSERT INTO dbo.DimLocation (Country, City, Region, IsEU)
    SELECT Country, City,
           CASE WHEN Country IN (N'United States', N'Canada') THEN N'North America'
                WHEN Country IN (N'Australia', N'Japan')      THEN N'Asia-Pacific'
                ELSE N'Europe' END,
           CASE WHEN Country IN (N'Bulgaria', N'Germany', N'France', N'Italy', N'Spain',
                                 N'Netherlands', N'Poland', N'Greece') THEN 1 ELSE 0 END
    FROM (SELECT Country, City FROM eBayDB.dbo.Users
          UNION
          SELECT ShippingCountry, ShippingCity FROM eBayDB.dbo.Orders) x;

    /* ---------- 3. DimUser ---------- */
    INSERT INTO dbo.DimUser (UserID, Username, FullName, Country, City, IsSeller, IsActive, RegistrationDate,
                             RegistrationYear, FeedbackScore, PositivePercent, SellerTier)
    SELECT u.UserID, u.Username, CONCAT(u.FirstName, N' ', u.LastName), u.Country, u.City, u.IsSeller, u.IsActive,
           CAST(u.RegistrationDate AS DATE), YEAR(u.RegistrationDate), u.FeedbackScore, pp.Pct,
           CASE WHEN u.IsSeller = 0                          THEN N'Buyer only'
                WHEN pp.Pct >= 98 AND u.FeedbackScore >= 20  THEN N'Top Rated'
                WHEN pp.Pct >= 95                            THEN N'Above Standard'
                WHEN pp.Pct IS NULL OR pp.Pct >= 90          THEN N'Standard'
                ELSE N'Below Standard' END
    FROM eBayDB.dbo.Users u
    CROSS APPLY (SELECT eBayDB.dbo.fn_GetSellerPositivePercent(u.UserID) AS Pct) pp;

    /* ---------- 4. DimCategory (с главната категория) ---------- */
    INSERT INTO dbo.DimCategory (CategoryID, CategoryName, MainCategoryID, MainCategoryName)
    SELECT c.CategoryID, c.Name, COALESCE(p.CategoryID, c.CategoryID), COALESCE(p.Name, c.Name)
    FROM eBayDB.dbo.Categories c
    LEFT JOIN eBayDB.dbo.Categories p ON p.CategoryID = c.ParentCategoryID;

    /* ---------- 5. DimListing ---------- */
    INSERT INTO dbo.DimListing (ListingID, Title, ListingFormat, ItemCondition, HasBuyItNow, ListingStatus,
                                DurationDays, PriceBand)
    SELECT l.ListingID, l.Title, l.ListingFormat, l.ItemCondition,
           CASE WHEN l.BuyItNowPrice IS NULL THEN 0 ELSE 1 END, l.Status,
           DATEDIFF(DAY, l.StartDate, l.EndDate),
           CASE WHEN l.CurrentPrice <   50 THEN N'1) < 50'
                WHEN l.CurrentPrice <  200 THEN N'2) 50 - 199'
                WHEN l.CurrentPrice <  500 THEN N'3) 200 - 499'
                WHEN l.CurrentPrice < 1000 THEN N'4) 500 - 999'
                ELSE N'5) 1000+' END
    FROM eBayDB.dbo.Listings l;

    /* ---------- 6. Статични измерения ---------- */
    INSERT INTO dbo.DimPaymentMethod (PaymentMethodKey, PaymentMethod, PaymentType) VALUES
        (0, N'Not paid', N'Unknown'), (1, N'PayPal', N'Digital wallet'), (2, N'Credit Card', N'Card'),
        (3, N'Debit Card', N'Card'), (4, N'Apple Pay', N'Digital wallet'), (5, N'Google Pay', N'Digital wallet');

    INSERT INTO dbo.DimCarrier (CarrierKey, CarrierName, CarrierType) VALUES (0, N'Not shipped', N'Unknown');
    INSERT INTO dbo.DimCarrier (CarrierKey, CarrierName, CarrierType)
    SELECT ROW_NUMBER() OVER (ORDER BY Carrier), Carrier,
           CASE WHEN Carrier IN (N'DHL Express', N'FedEx', N'UPS') THEN N'Express'
                WHEN Carrier IN (N'USPS', N'Royal Mail')           THEN N'Postal'
                ELSE N'Courier' END
    FROM (SELECT DISTINCT Carrier FROM eBayDB.dbo.Shipments) c;

    INSERT INTO dbo.DimOrderStatus (OrderStatusKey, StatusName, StatusGroup, IsRevenue) VALUES
        (1, N'Pending', N'Open', 0), (2, N'Paid', N'Open', 1), (3, N'Shipped', N'Open', 1),
        (4, N'Delivered', N'Completed', 1), (5, N'Cancelled', N'Lost sale', 0), (6, N'Returned', N'Lost sale', 0);

    /* ---------- 7. FactSales ---------- */
    INSERT INTO dbo.FactSales (OrderDateKey, BuyerKey, SellerKey, CategoryKey, ListingKey, BuyerLocationKey,
                               PaymentMethodKey, CarrierKey, OrderStatusKey, OrderID, OrderItemID, Quantity,
                               UnitPrice, SalesAmount, ShippingAmount, GrossAmount, FinalValueFee, DeliveryDays)
    SELECT YEAR(o.OrderDate) * 10000 + MONTH(o.OrderDate) * 100 + DAY(o.OrderDate),
           db.UserKey, ds.UserKey, dc.CategoryKey, dl.ListingKey, loc.LocationKey,
           ISNULL(pm.PaymentMethodKey, 0), ISNULL(car.CarrierKey, 0), st.OrderStatusKey,
           o.OrderID, oi.OrderItemID, oi.Quantity, oi.UnitPrice,
           oi.Quantity * oi.UnitPrice,
           oi.ShippingCost,
           oi.Quantity * oi.UnitPrice + oi.ShippingCost,
           ROUND((oi.Quantity * oi.UnitPrice + oi.ShippingCost) * 0.1325, 2),
           CASE WHEN sh.DeliveredDate IS NOT NULL
                THEN CAST(DATEDIFF(MINUTE, o.OrderDate, sh.DeliveredDate) / 1440.0 AS DECIMAL(6,2)) END
    FROM eBayDB.dbo.OrderItems oi
    INNER JOIN eBayDB.dbo.Orders o   ON o.OrderID = oi.OrderID
    INNER JOIN eBayDB.dbo.Listings l ON l.ListingID = oi.ListingID
    OUTER APPLY (SELECT TOP (1) p.PaymentMethod FROM eBayDB.dbo.Payments p
                 WHERE p.OrderID = o.OrderID ORDER BY p.PaymentDate DESC) p
    LEFT JOIN eBayDB.dbo.Shipments sh ON sh.OrderID = o.OrderID
    INNER JOIN dbo.DimUser db         ON db.UserID = o.BuyerID
    INNER JOIN dbo.DimUser ds         ON ds.UserID = l.SellerID
    INNER JOIN dbo.DimCategory dc     ON dc.CategoryID = l.CategoryID
    INNER JOIN dbo.DimListing dl      ON dl.ListingID = l.ListingID
    INNER JOIN dbo.DimLocation loc    ON loc.Country = o.ShippingCountry AND loc.City = o.ShippingCity
    LEFT  JOIN dbo.DimPaymentMethod pm ON pm.PaymentMethod = p.PaymentMethod
    LEFT  JOIN dbo.DimCarrier car     ON car.CarrierName = sh.Carrier
    INNER JOIN dbo.DimOrderStatus st  ON st.StatusName = o.Status;

    /* ---------- 8. FactBids ---------- */
    WITH BidsRanked AS
    (
        SELECT b.BidID, b.ListingID, b.BidderID, b.BidAmount, b.BidTime,
               l.SellerID, l.CategoryID, l.EndDate, l.Status, l.StartPrice,
               ROW_NUMBER() OVER (PARTITION BY b.ListingID ORDER BY b.BidAmount, b.BidTime, b.BidID) AS Seq,
               ROW_NUMBER() OVER (PARTITION BY b.ListingID ORDER BY b.BidAmount DESC, b.BidTime, b.BidID) AS Rnk,
               LAG(b.BidAmount) OVER (PARTITION BY b.ListingID ORDER BY b.BidAmount, b.BidTime, b.BidID) AS PrevAmount
        FROM eBayDB.dbo.Bids b
        INNER JOIN eBayDB.dbo.Listings l ON l.ListingID = b.ListingID
    )
    INSERT INTO dbo.FactBids (BidDateKey, BidderKey, SellerKey, ListingKey, CategoryKey, BidderLocationKey,
                              BidID, BidAmount, BidSequence, IncrementAmount, HoursBeforeEnd, IsWinningBid)
    SELECT YEAR(b.BidTime) * 10000 + MONTH(b.BidTime) * 100 + DAY(b.BidTime),
           bidder.UserKey, seller.UserKey, dl.ListingKey, dc.CategoryKey, loc.LocationKey,
           b.BidID, b.BidAmount, b.Seq,
           b.BidAmount - ISNULL(b.PrevAmount, b.StartPrice),
           CAST(DATEDIFF(MINUTE, b.BidTime, b.EndDate) / 60.0 AS DECIMAL(8,2)),
           CASE WHEN b.Rnk = 1 AND b.Status = N'Sold' THEN 1 ELSE 0 END
    FROM BidsRanked b
    INNER JOIN dbo.DimUser bidder  ON bidder.UserID = b.BidderID
    INNER JOIN dbo.DimUser seller  ON seller.UserID = b.SellerID
    INNER JOIN dbo.DimListing dl   ON dl.ListingID = b.ListingID
    INNER JOIN dbo.DimCategory dc  ON dc.CategoryID = b.CategoryID
    INNER JOIN dbo.DimLocation loc ON loc.Country = bidder.Country AND loc.City = bidder.City;

    /* ---------- 9. FactFeedback ---------- */
    INSERT INTO dbo.FactFeedback (FeedbackDateKey, FromUserKey, ToUserKey, ListingKey, CategoryKey, FeedbackID,
                                  FeedbackRole, Rating, IsPositive, IsNeutral, IsNegative, HasComment, DaysAfterOrder)
    SELECT YEAR(f.CreatedAt) * 10000 + MONTH(f.CreatedAt) * 100 + DAY(f.CreatedAt),
           fu.UserKey, tu.UserKey, dl.ListingKey, dc.CategoryKey, f.FeedbackID,
           CASE WHEN f.FromUserID = o.BuyerID THEN N'Buyer->Seller' ELSE N'Seller->Buyer' END,
           f.Rating,
           CASE WHEN f.Rating =  1 THEN 1 ELSE 0 END,
           CASE WHEN f.Rating =  0 THEN 1 ELSE 0 END,
           CASE WHEN f.Rating = -1 THEN 1 ELSE 0 END,
           CASE WHEN LEN(ISNULL(f.Comment, N'')) > 0 THEN 1 ELSE 0 END,
           CAST(DATEDIFF(MINUTE, o.OrderDate, f.CreatedAt) / 1440.0 AS DECIMAL(6,2))
    FROM eBayDB.dbo.Feedback f
    INNER JOIN eBayDB.dbo.OrderItems oi ON oi.OrderItemID = f.OrderItemID
    INNER JOIN eBayDB.dbo.Orders o      ON o.OrderID = oi.OrderID
    INNER JOIN eBayDB.dbo.Listings l    ON l.ListingID = oi.ListingID
    INNER JOIN dbo.DimUser fu           ON fu.UserID = f.FromUserID
    INNER JOIN dbo.DimUser tu           ON tu.UserID = f.ToUserID
    INNER JOIN dbo.DimListing dl        ON dl.ListingID = l.ListingID
    INNER JOIN dbo.DimCategory dc       ON dc.CategoryID = l.CategoryID;

    /* ---------- 10. FactListings ---------- */
    INSERT INTO dbo.FactListings (StartDateKey, EndDateKey, SellerKey, CategoryKey, ListingKey, SellerLocationKey,
                                  StartPrice, FinalPrice, QuantityListed, QuantitySold, BidCount, UniqueBidders,
                                  WatchCount, ViewCount, IsSold)
    SELECT YEAR(l.StartDate) * 10000 + MONTH(l.StartDate) * 100 + DAY(l.StartDate),
           YEAR(l.EndDate)   * 10000 + MONTH(l.EndDate)   * 100 + DAY(l.EndDate),
           s.UserKey, dc.CategoryKey, dl.ListingKey, loc.LocationKey,
           l.StartPrice, l.CurrentPrice, l.Quantity, l.QuantitySold,
           ISNULL(bc.BidCount, 0), ISNULL(bc.UniqueBidders, 0), ISNULL(wc.WatchCount, 0), l.ViewCount,
           CASE WHEN l.QuantitySold > 0 THEN 1 ELSE 0 END
    FROM eBayDB.dbo.Listings l
    OUTER APPLY (SELECT COUNT(*) AS BidCount, COUNT(DISTINCT b.BidderID) AS UniqueBidders
                 FROM eBayDB.dbo.Bids b WHERE b.ListingID = l.ListingID) bc
    OUTER APPLY (SELECT COUNT(*) AS WatchCount
                 FROM eBayDB.dbo.Watchlist w WHERE w.ListingID = l.ListingID) wc
    INNER JOIN dbo.DimUser s       ON s.UserID = l.SellerID
    INNER JOIN dbo.DimCategory dc  ON dc.CategoryID = l.CategoryID
    INNER JOIN dbo.DimListing dl   ON dl.ListingID = l.ListingID
    INNER JOIN dbo.DimLocation loc ON loc.Country = s.Country AND loc.City = s.City;

    COMMIT TRANSACTION;

    UPDATE dbo.EtlLog
    SET FinishedAt   = SYSDATETIME(),
        SalesRows    = (SELECT COUNT(*) FROM dbo.FactSales),
        BidRows      = (SELECT COUNT(*) FROM dbo.FactBids),
        FeedbackRows = (SELECT COUNT(*) FROM dbo.FactFeedback),
        ListingRows  = (SELECT COUNT(*) FROM dbo.FactListings)
    WHERE LoadID = @LoadID;

    SELECT * FROM dbo.EtlLog WHERE LoadID = @LoadID;
END;
GO

/* Първоначално зареждане */
EXEC dbo.sp_LoadDW;
GO

/* Бърза проверка: оборот по година и главна категория */
SELECT d.[Year], c.MainCategoryName, SUM(f.SalesAmount) AS Revenue, COUNT(*) AS Items
FROM dbo.FactSales f
JOIN dbo.DimDate d        ON d.DateKey = f.OrderDateKey
JOIN dbo.DimCategory c    ON c.CategoryKey = f.CategoryKey
JOIN dbo.DimOrderStatus s ON s.OrderStatusKey = f.OrderStatusKey AND s.IsRevenue = 1
GROUP BY d.[Year], c.MainCategoryName
ORDER BY d.[Year], Revenue DESC;
GO
