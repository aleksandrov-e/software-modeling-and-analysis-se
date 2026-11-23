/* =====================================================================
   Курсова работа – eBay (онлайн платформа за търгове и покупки)
   Студент: Емил Александров, ф.н. 2401321025
   Файл 01: Създаване на OLTP базата данни eBayDB и всички таблици
   СУБД:   Microsoft SQL Server 2019+ (тествано за T-SQL синтаксис)
   ===================================================================== */

USE master;
GO

IF DB_ID(N'eBayDB') IS NOT NULL
BEGIN
    ALTER DATABASE eBayDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE eBayDB;
END
GO

CREATE DATABASE eBayDB;
GO

USE eBayDB;
GO

/* ---------------------------------------------------------------------
   1. Users – потребители (купувачи и продавачи)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.Users
(
    UserID            INT            IDENTITY(1,1) NOT NULL,
    Username          NVARCHAR(50)   NOT NULL,
    Email             NVARCHAR(100)  NOT NULL,
    PasswordHash      NVARCHAR(256)  NOT NULL,
    FirstName         NVARCHAR(50)   NOT NULL,
    LastName          NVARCHAR(50)   NOT NULL,
    Phone             NVARCHAR(30)   NULL,
    Country           NVARCHAR(60)   NOT NULL,
    City              NVARCHAR(60)   NOT NULL,
    RegistrationDate  DATETIME2(0)   NOT NULL CONSTRAINT DF_Users_RegistrationDate DEFAULT (SYSDATETIME()),
    IsSeller          BIT            NOT NULL CONSTRAINT DF_Users_IsSeller DEFAULT (0),
    FeedbackScore     INT            NOT NULL CONSTRAINT DF_Users_FeedbackScore DEFAULT (0),
    IsActive          BIT            NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT (1),
    CONSTRAINT PK_Users PRIMARY KEY (UserID),
    CONSTRAINT UQ_Users_Username UNIQUE (Username),
    CONSTRAINT UQ_Users_Email UNIQUE (Email),
    CONSTRAINT CK_Users_Email CHECK (Email LIKE N'%_@_%._%')
);
GO

/* ---------------------------------------------------------------------
   2. Categories – йерархични категории (саморефериращ FK)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.Categories
(
    CategoryID        INT            IDENTITY(1,1) NOT NULL,
    ParentCategoryID  INT            NULL,
    Name              NVARCHAR(100)  NOT NULL,
    Description       NVARCHAR(400)  NULL,
    IsActive          BIT            NOT NULL CONSTRAINT DF_Categories_IsActive DEFAULT (1),
    CONSTRAINT PK_Categories PRIMARY KEY (CategoryID),
    CONSTRAINT FK_Categories_Parent FOREIGN KEY (ParentCategoryID) REFERENCES dbo.Categories (CategoryID),
    CONSTRAINT UQ_Categories_Name UNIQUE (ParentCategoryID, Name)
);
GO

/* ---------------------------------------------------------------------
   3. Listings – обяви (търг или „Купи сега“)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.Listings
(
    ListingID         INT            IDENTITY(1,1) NOT NULL,
    SellerID          INT            NOT NULL,
    CategoryID        INT            NOT NULL,
    Title             NVARCHAR(150)  NOT NULL,
    Description       NVARCHAR(MAX)  NULL,
    ItemCondition     NVARCHAR(20)   NOT NULL,
    ListingFormat     NVARCHAR(10)   NOT NULL,
    StartPrice        DECIMAL(10,2)  NOT NULL,
    BuyItNowPrice     DECIMAL(10,2)  NULL,
    CurrentPrice      DECIMAL(10,2)  NOT NULL,
    Quantity          INT            NOT NULL CONSTRAINT DF_Listings_Quantity DEFAULT (1),
    QuantitySold      INT            NOT NULL CONSTRAINT DF_Listings_QuantitySold DEFAULT (0),
    ShippingCost      DECIMAL(8,2)   NOT NULL CONSTRAINT DF_Listings_ShippingCost DEFAULT (0),
    StartDate         DATETIME2(0)   NOT NULL CONSTRAINT DF_Listings_StartDate DEFAULT (SYSDATETIME()),
    EndDate           DATETIME2(0)   NOT NULL,
    Status            NVARCHAR(10)   NOT NULL CONSTRAINT DF_Listings_Status DEFAULT (N'Active'),
    ViewCount         INT            NOT NULL CONSTRAINT DF_Listings_ViewCount DEFAULT (0),
    CONSTRAINT PK_Listings PRIMARY KEY (ListingID),
    CONSTRAINT FK_Listings_Seller   FOREIGN KEY (SellerID)   REFERENCES dbo.Users (UserID),
    CONSTRAINT FK_Listings_Category FOREIGN KEY (CategoryID) REFERENCES dbo.Categories (CategoryID),
    CONSTRAINT CK_Listings_Condition CHECK (ItemCondition IN (N'New', N'Used', N'Refurbished', N'For parts')),
    CONSTRAINT CK_Listings_Format    CHECK (ListingFormat IN (N'Auction', N'BuyItNow')),
    CONSTRAINT CK_Listings_Status    CHECK (Status IN (N'Active', N'Sold', N'Ended', N'Cancelled')),
    CONSTRAINT CK_Listings_Prices    CHECK (StartPrice > 0 AND CurrentPrice >= StartPrice
                                            AND (BuyItNowPrice IS NULL OR BuyItNowPrice >= StartPrice)),
    CONSTRAINT CK_Listings_Quantity  CHECK (Quantity >= 1 AND QuantitySold BETWEEN 0 AND Quantity),
    CONSTRAINT CK_Listings_Auction   CHECK (ListingFormat = N'BuyItNow' OR Quantity = 1),
    CONSTRAINT CK_Listings_Dates     CHECK (EndDate > StartDate)
);
GO

/* ---------------------------------------------------------------------
   4. Bids – наддавания (M:N между Users и Listings)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.Bids
(
    BidID             INT            IDENTITY(1,1) NOT NULL,
    ListingID         INT            NOT NULL,
    BidderID          INT            NOT NULL,
    BidAmount         DECIMAL(10,2)  NOT NULL,
    BidTime           DATETIME2(0)   NOT NULL CONSTRAINT DF_Bids_BidTime DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Bids PRIMARY KEY (BidID),
    CONSTRAINT FK_Bids_Listing FOREIGN KEY (ListingID) REFERENCES dbo.Listings (ListingID),
    CONSTRAINT FK_Bids_Bidder  FOREIGN KEY (BidderID)  REFERENCES dbo.Users (UserID),
    CONSTRAINT CK_Bids_Amount  CHECK (BidAmount > 0)
);
GO

/* ---------------------------------------------------------------------
   5. Watchlist – следени обяви (M:N между Users и Listings)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.Watchlist
(
    UserID            INT            NOT NULL,
    ListingID         INT            NOT NULL,
    AddedDate         DATETIME2(0)   NOT NULL CONSTRAINT DF_Watchlist_AddedDate DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Watchlist PRIMARY KEY (UserID, ListingID),
    CONSTRAINT FK_Watchlist_User    FOREIGN KEY (UserID)    REFERENCES dbo.Users (UserID),
    CONSTRAINT FK_Watchlist_Listing FOREIGN KEY (ListingID) REFERENCES dbo.Listings (ListingID)   -- изтриването се обработва от trg_Listings_SoftDelete
);
GO

/* ---------------------------------------------------------------------
   6. Orders – поръчки
   --------------------------------------------------------------------- */
CREATE TABLE dbo.Orders
(
    OrderID           INT            IDENTITY(1,1) NOT NULL,
    BuyerID           INT            NOT NULL,
    OrderDate         DATETIME2(0)   NOT NULL CONSTRAINT DF_Orders_OrderDate DEFAULT (SYSDATETIME()),
    Status            NVARCHAR(10)   NOT NULL CONSTRAINT DF_Orders_Status DEFAULT (N'Pending'),
    ShippingAddress   NVARCHAR(200)  NOT NULL,
    ShippingCity      NVARCHAR(60)   NOT NULL,
    ShippingCountry   NVARCHAR(60)   NOT NULL,
    TotalAmount       DECIMAL(12,2)  NOT NULL CONSTRAINT DF_Orders_TotalAmount DEFAULT (0),
    CONSTRAINT PK_Orders PRIMARY KEY (OrderID),
    CONSTRAINT FK_Orders_Buyer FOREIGN KEY (BuyerID) REFERENCES dbo.Users (UserID),
    CONSTRAINT CK_Orders_Status CHECK (Status IN (N'Pending', N'Paid', N'Shipped', N'Delivered', N'Cancelled', N'Returned'))
);
GO

/* ---------------------------------------------------------------------
   7. OrderItems – редове в поръчка (M:N между Orders и Listings)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.OrderItems
(
    OrderItemID       INT            IDENTITY(1,1) NOT NULL,
    OrderID           INT            NOT NULL,
    ListingID         INT            NOT NULL,
    Quantity          INT            NOT NULL CONSTRAINT DF_OrderItems_Quantity DEFAULT (1),
    UnitPrice         DECIMAL(10,2)  NOT NULL,
    ShippingCost      DECIMAL(8,2)   NOT NULL CONSTRAINT DF_OrderItems_ShippingCost DEFAULT (0),
    CONSTRAINT PK_OrderItems PRIMARY KEY (OrderItemID),
    CONSTRAINT FK_OrderItems_Order   FOREIGN KEY (OrderID)   REFERENCES dbo.Orders (OrderID) ON DELETE CASCADE,
    CONSTRAINT FK_OrderItems_Listing FOREIGN KEY (ListingID) REFERENCES dbo.Listings (ListingID),
    CONSTRAINT UQ_OrderItems_OrderListing UNIQUE (OrderID, ListingID),
    CONSTRAINT CK_OrderItems_Quantity CHECK (Quantity > 0),
    CONSTRAINT CK_OrderItems_Price    CHECK (UnitPrice > 0 AND ShippingCost >= 0)
);
GO

/* ---------------------------------------------------------------------
   8. Payments – плащания (1:N с Orders)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.Payments
(
    PaymentID         INT            IDENTITY(1,1) NOT NULL,
    OrderID           INT            NOT NULL,
    PaymentMethod     NVARCHAR(20)   NOT NULL,
    Amount            DECIMAL(12,2)  NOT NULL,
    PaymentDate       DATETIME2(0)   NOT NULL CONSTRAINT DF_Payments_PaymentDate DEFAULT (SYSDATETIME()),
    Status            NVARCHAR(10)   NOT NULL CONSTRAINT DF_Payments_Status DEFAULT (N'Completed'),
    TransactionRef    NVARCHAR(40)   NOT NULL,
    CONSTRAINT PK_Payments PRIMARY KEY (PaymentID),
    CONSTRAINT FK_Payments_Order FOREIGN KEY (OrderID) REFERENCES dbo.Orders (OrderID) ON DELETE CASCADE,
    CONSTRAINT UQ_Payments_TransactionRef UNIQUE (TransactionRef),
    CONSTRAINT CK_Payments_Method CHECK (PaymentMethod IN (N'PayPal', N'Credit Card', N'Debit Card', N'Apple Pay', N'Google Pay')),
    CONSTRAINT CK_Payments_Status CHECK (Status IN (N'Completed', N'Refunded', N'Failed')),
    CONSTRAINT CK_Payments_Amount CHECK (Amount > 0)
);
GO

/* ---------------------------------------------------------------------
   9. Shipments – доставки (1:1 с Orders)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.Shipments
(
    ShipmentID        INT            IDENTITY(1,1) NOT NULL,
    OrderID           INT            NOT NULL,
    Carrier           NVARCHAR(30)   NOT NULL,
    TrackingNumber    NVARCHAR(40)   NOT NULL,
    ShippedDate       DATETIME2(0)   NOT NULL,
    DeliveredDate     DATETIME2(0)   NULL,
    ShippingStatus    NVARCHAR(12)   NOT NULL CONSTRAINT DF_Shipments_Status DEFAULT (N'In transit'),
    CONSTRAINT PK_Shipments PRIMARY KEY (ShipmentID),
    CONSTRAINT FK_Shipments_Order FOREIGN KEY (OrderID) REFERENCES dbo.Orders (OrderID) ON DELETE CASCADE,
    CONSTRAINT UQ_Shipments_Order UNIQUE (OrderID),
    CONSTRAINT UQ_Shipments_Tracking UNIQUE (TrackingNumber),
    CONSTRAINT CK_Shipments_Status CHECK (ShippingStatus IN (N'In transit', N'Delivered', N'Returned', N'Lost')),
    CONSTRAINT CK_Shipments_Dates  CHECK (DeliveredDate IS NULL OR DeliveredDate >= ShippedDate)
);
GO

/* ---------------------------------------------------------------------
   10. Feedback – обратна връзка (оценка) между купувач и продавач
   --------------------------------------------------------------------- */
CREATE TABLE dbo.Feedback
(
    FeedbackID        INT            IDENTITY(1,1) NOT NULL,
    OrderItemID       INT            NOT NULL,
    FromUserID        INT            NOT NULL,
    ToUserID          INT            NOT NULL,
    Rating            SMALLINT       NOT NULL,
    Comment           NVARCHAR(500)  NULL,
    CreatedAt         DATETIME2(0)   NOT NULL CONSTRAINT DF_Feedback_CreatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Feedback PRIMARY KEY (FeedbackID),
    CONSTRAINT FK_Feedback_OrderItem FOREIGN KEY (OrderItemID) REFERENCES dbo.OrderItems (OrderItemID),
    CONSTRAINT FK_Feedback_FromUser  FOREIGN KEY (FromUserID)  REFERENCES dbo.Users (UserID),
    CONSTRAINT FK_Feedback_ToUser    FOREIGN KEY (ToUserID)    REFERENCES dbo.Users (UserID),
    CONSTRAINT UQ_Feedback_OrderItemFrom UNIQUE (OrderItemID, FromUserID),
    CONSTRAINT CK_Feedback_Rating CHECK (Rating IN (-1, 0, 1)),   -- -1 отрицателна, 0 неутрална, 1 положителна
    CONSTRAINT CK_Feedback_Users  CHECK (FromUserID <> ToUserID)
);
GO

/* ---------------------------------------------------------------------
   Индекси за често използвани заявки (допълнение)
   --------------------------------------------------------------------- */
CREATE INDEX IX_Listings_Seller        ON dbo.Listings (SellerID);
CREATE INDEX IX_Listings_Category      ON dbo.Listings (CategoryID) INCLUDE (Status, CurrentPrice);
CREATE INDEX IX_Listings_StatusEndDate ON dbo.Listings (Status, EndDate);
CREATE INDEX IX_Bids_Listing           ON dbo.Bids (ListingID, BidAmount DESC);
CREATE INDEX IX_Bids_Bidder            ON dbo.Bids (BidderID);
CREATE INDEX IX_Orders_Buyer           ON dbo.Orders (BuyerID, OrderDate);
CREATE INDEX IX_OrderItems_Listing     ON dbo.OrderItems (ListingID);
CREATE INDEX IX_Payments_Order         ON dbo.Payments (OrderID);
CREATE INDEX IX_Feedback_ToUser        ON dbo.Feedback (ToUserID) INCLUDE (Rating);
GO

PRINT N'eBayDB и всички таблици са създадени успешно.';
GO
