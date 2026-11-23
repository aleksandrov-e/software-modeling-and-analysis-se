/* =====================================================================
   Курсова работа – eBay | ф.н. 2401321025
   Файл 04: Демонстрация на функциите, процедурите и тригерите
            + примерни аналитични заявки.
   По желание; изпълнявайте след 03_seed_data.sql.
   (Създава 1 демо обява, 1 наддаване и 1 поръчка.)
   ===================================================================== */

USE eBayDB;
GO
SET NOCOUNT ON;
GO

/* ---------- 1. Функции ---------- */
PRINT N'--- fn_GetBidIncrement / fn_GetSellerPositivePercent ---';
SELECT dbo.fn_GetBidIncrement(3.50)   AS IncrementAt3_50,
       dbo.fn_GetBidIncrement(180.00) AS IncrementAt180,
       dbo.fn_GetBidIncrement(1500)   AS IncrementAt1500;

SELECT TOP (10) UserID, Username, FeedbackScore,
       dbo.fn_GetSellerPositivePercent(UserID) AS PositivePercent
FROM dbo.Users
WHERE IsSeller = 1
ORDER BY FeedbackScore DESC;

PRINT N'--- fn_GetActiveListingsByCategory (1 = Electronics + подкатегориите) ---';
SELECT * FROM dbo.fn_GetActiveListingsByCategory(1) ORDER BY EndDate;
GO

/* ---------- 2. Демо търг: sp_PlaceBid + тригер trg_Bids_AfterInsert ---------- */
DECLARE @DemoListing INT, @BidID INT;

INSERT INTO dbo.Listings (SellerID, CategoryID, Title, Description, ItemCondition, ListingFormat,
                          StartPrice, BuyItNowPrice, CurrentPrice, ShippingCost, EndDate)
VALUES (1, 2, N'DEMO: Apple iPhone 15 128GB (demo auction)', N'Demo listing for the course work',
        N'Used', N'Auction', 300.00, 520.00, 300.00, 9.99, DATEADD(DAY, 7, SYSDATETIME()));
SET @DemoListing = SCOPE_IDENTITY();

SELECT dbo.fn_GetMinNextBid(@DemoListing) AS MinFirstBid;                -- 300.00

EXEC dbo.sp_PlaceBid @ListingID = @DemoListing, @BidderID = 50, @Amount = 300.00, @BidID = @BidID OUTPUT;
EXEC dbo.sp_PlaceBid @ListingID = @DemoListing, @BidderID = 51, @Amount = 320.00;

SELECT ListingID, Title, StartPrice, CurrentPrice,                       -- CurrentPrice = 320 (тригер)
       dbo.fn_GetMinNextBid(ListingID) AS MinNextBid                     -- 325.00
FROM dbo.Listings WHERE ListingID = @DemoListing;

-- Невалидни операции – грешките се прихващат
BEGIN TRY
    EXEC dbo.sp_PlaceBid @ListingID = @DemoListing, @BidderID = 52, @Amount = 321.00;   -- под минимума
END TRY
BEGIN CATCH
    PRINT N'Очаквана грешка: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    INSERT INTO dbo.Bids (ListingID, BidderID, BidAmount) VALUES (@DemoListing, 1, 999.00);  -- продавачът наддава
END TRY
BEGIN CATCH
    PRINT N'Очаквана грешка от тригера: ' + ERROR_MESSAGE();
END CATCH;

/* ---------- 3. sp_BuyItNow + тригер trg_OrderItems_RecalcTotal ---------- */
DECLARE @OrderID INT;
EXEC dbo.sp_BuyItNow @BuyerID = 60, @ListingID = @DemoListing, @Quantity = 1,
                     @PaymentMethod = N'PayPal', @ShippingAddress = N'1 Vitosha Blvd',
                     @OrderID = @OrderID OUTPUT;

SELECT o.OrderID, o.Status, o.TotalAmount, p.PaymentMethod, p.Amount, l.Status AS ListingStatus
FROM dbo.Orders o
JOIN dbo.Payments p ON p.OrderID = o.OrderID
JOIN dbo.OrderItems oi ON oi.OrderID = o.OrderID
JOIN dbo.Listings l ON l.ListingID = oi.ListingID
WHERE o.OrderID = @OrderID;                                              -- TotalAmount = 529.99

/* ---------- 4. sp_ShipOrder + тригер trg_Shipments_SyncOrderStatus ---------- */
EXEC dbo.sp_ShipOrder @OrderID = @OrderID, @Carrier = N'Speedy', @TrackingNumber = N'SP-DEMO-0001';
SELECT OrderID, Status FROM dbo.Orders WHERE OrderID = @OrderID;          -- Shipped

UPDATE dbo.Shipments SET DeliveredDate = SYSDATETIME(), ShippingStatus = N'Delivered' WHERE OrderID = @OrderID;
SELECT OrderID, Status FROM dbo.Orders WHERE OrderID = @OrderID;          -- Delivered

/* ---------- 5. sp_LeaveFeedback + тригер trg_Feedback_UpdateScore ---------- */
DECLARE @OrderItemID INT = (SELECT OrderItemID FROM dbo.OrderItems WHERE OrderID = @OrderID);
SELECT UserID, Username, FeedbackScore AS ScoreBefore FROM dbo.Users WHERE UserID = 1;
EXEC dbo.sp_LeaveFeedback @OrderItemID = @OrderItemID, @FromUserID = 60, @Rating = 1, @Comment = N'Great seller!';
SELECT UserID, Username, FeedbackScore AS ScoreAfter FROM dbo.Users WHERE UserID = 1;   -- +1
GO

/* ---------- 6. Тригер trg_Listings_SoftDelete ---------- */
DECLARE @Sold INT = (SELECT TOP (1) ListingID FROM dbo.Listings WHERE Status = N'Sold' ORDER BY ListingID);
DELETE FROM dbo.Listings WHERE ListingID = @Sold;                          -- не се изтрива физически
SELECT ListingID, Status FROM dbo.Listings WHERE ListingID = @Sold;        -- Cancelled
UPDATE dbo.Listings SET Status = N'Sold' WHERE ListingID = @Sold;          -- връщаме стойността
GO

/* ---------- 7. sp_GetSellerReport и sp_CloseEndedAuctions ---------- */
EXEC dbo.sp_GetSellerReport @SellerID = 1, @From = '2025-01-01', @To = '2025-12-31';
EXEC dbo.sp_CloseEndedAuctions;     -- приключва търговете, изтекли след датата на данните
GO

/* ---------- 8. Аналитични заявки ---------- */
-- Топ 10 продавачи по оборот
SELECT TOP (10) * FROM dbo.vw_SellerPerformance ORDER BY Revenue DESC;

-- Оборот по месеци
SELECT * FROM dbo.vw_MonthlySales ORDER BY [Year], [Month];

-- Оборот по главна категория
SELECT pc.Name AS MainCategory, COUNT(*) AS ItemsSold, SUM(oi.Quantity * oi.UnitPrice) AS Revenue
FROM dbo.OrderItems oi
JOIN dbo.Orders o      ON o.OrderID = oi.OrderID AND o.Status NOT IN (N'Cancelled', N'Returned')
JOIN dbo.Listings l    ON l.ListingID = oi.ListingID
JOIN dbo.Categories c  ON c.CategoryID = l.CategoryID
JOIN dbo.Categories pc ON pc.CategoryID = c.ParentCategoryID
GROUP BY pc.Name
ORDER BY Revenue DESC;

-- Търгове: средна крайна цена спрямо началната
SELECT c.Name AS Category, COUNT(*) AS SoldAuctions,
       AVG(l.StartPrice) AS AvgStart, AVG(l.CurrentPrice) AS AvgFinal,
       AVG(l.CurrentPrice / l.StartPrice) AS AvgMultiplier
FROM dbo.Listings l
JOIN dbo.Categories c ON c.CategoryID = l.CategoryID
WHERE l.ListingFormat = N'Auction' AND l.Status = N'Sold'
GROUP BY c.Name
ORDER BY AvgMultiplier DESC;

-- Най-следени активни обяви
SELECT TOP (10) * FROM dbo.vw_ActiveListings ORDER BY Watchers DESC, BidCount DESC;
GO
