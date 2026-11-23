/* =====================================================================
   Курсова работа – eBay | ф.н. 2401321025
   Data Warehouse eBayDW – схема „съзвездие“ (fact constellation)
   4 таблици факти:     FactSales, FactBids, FactFeedback, FactListings
   8 таблици измерения: DimDate, DimUser, DimCategory, DimListing,
                        DimLocation, DimPaymentMethod, DimCarrier,
                        DimOrderStatus
   ===================================================================== */

USE master;
GO

IF DB_ID(N'eBayDW') IS NOT NULL
BEGIN
    ALTER DATABASE eBayDW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE eBayDW;
END
GO

CREATE DATABASE eBayDW;
GO

USE eBayDW;
GO

/* =====================================================================
   ИЗМЕРЕНИЯ
   ===================================================================== */

CREATE TABLE dbo.DimDate
(
    DateKey        INT           NOT NULL,      -- yyyymmdd
    FullDate       DATE          NOT NULL,
    DayOfMonth     TINYINT       NOT NULL,
    DayOfWeek      TINYINT       NOT NULL,      -- 1 = понеделник
    DayName        NVARCHAR(10)  NOT NULL,
    IsWeekend      BIT           NOT NULL,
    WeekOfYear     TINYINT       NOT NULL,
    MonthNumber    TINYINT       NOT NULL,
    MonthName      NVARCHAR(10)  NOT NULL,
    Quarter        TINYINT       NOT NULL,
    QuarterName    CHAR(2)       NOT NULL,
    [Year]         SMALLINT      NOT NULL,
    YearMonth      CHAR(7)       NOT NULL,      -- 2025-03
    CONSTRAINT PK_DimDate PRIMARY KEY (DateKey),
    CONSTRAINT UQ_DimDate_FullDate UNIQUE (FullDate)
);

CREATE TABLE dbo.DimLocation
(
    LocationKey    INT IDENTITY(1,1) NOT NULL,
    Country        NVARCHAR(60)  NOT NULL,
    City           NVARCHAR(60)  NOT NULL,
    Region         NVARCHAR(30)  NOT NULL,      -- Europe / North America / Asia-Pacific
    IsEU           BIT           NOT NULL,
    CONSTRAINT PK_DimLocation PRIMARY KEY (LocationKey),
    CONSTRAINT UQ_DimLocation UNIQUE (Country, City)
);

CREATE TABLE dbo.DimUser
(
    UserKey          INT IDENTITY(1,1) NOT NULL,
    UserID           INT           NOT NULL,    -- бизнес ключ от eBayDB
    Username         NVARCHAR(50)  NOT NULL,
    FullName         NVARCHAR(101) NOT NULL,
    Country          NVARCHAR(60)  NOT NULL,
    City             NVARCHAR(60)  NOT NULL,
    IsSeller         BIT           NOT NULL,
    IsActive         BIT           NOT NULL,
    RegistrationDate DATE          NOT NULL,
    RegistrationYear SMALLINT      NOT NULL,
    FeedbackScore    INT           NOT NULL,
    PositivePercent  DECIMAL(5,2)  NULL,
    SellerTier       NVARCHAR(20)  NOT NULL,    -- Top Rated / Above Standard / Standard / Below Standard / Buyer only
    CONSTRAINT PK_DimUser PRIMARY KEY (UserKey),
    CONSTRAINT UQ_DimUser_UserID UNIQUE (UserID)
);

CREATE TABLE dbo.DimCategory
(
    CategoryKey      INT IDENTITY(1,1) NOT NULL,
    CategoryID       INT           NOT NULL,
    CategoryName     NVARCHAR(100) NOT NULL,
    MainCategoryID   INT           NOT NULL,
    MainCategoryName NVARCHAR(100) NOT NULL,
    CONSTRAINT PK_DimCategory PRIMARY KEY (CategoryKey),
    CONSTRAINT UQ_DimCategory_CategoryID UNIQUE (CategoryID)
);

CREATE TABLE dbo.DimListing
(
    ListingKey       INT IDENTITY(1,1) NOT NULL,
    ListingID        INT           NOT NULL,
    Title            NVARCHAR(150) NOT NULL,
    ListingFormat    NVARCHAR(10)  NOT NULL,
    ItemCondition    NVARCHAR(20)  NOT NULL,
    HasBuyItNow      BIT           NOT NULL,
    ListingStatus    NVARCHAR(10)  NOT NULL,
    DurationDays     INT           NOT NULL,
    PriceBand        NVARCHAR(20)  NOT NULL,    -- < 50 / 50-199 / 200-499 / 500-999 / 1000+
    CONSTRAINT PK_DimListing PRIMARY KEY (ListingKey),
    CONSTRAINT UQ_DimListing_ListingID UNIQUE (ListingID)
);

CREATE TABLE dbo.DimPaymentMethod
(
    PaymentMethodKey INT           NOT NULL,
    PaymentMethod    NVARCHAR(20)  NOT NULL,
    PaymentType      NVARCHAR(20)  NOT NULL,    -- Card / Digital wallet / Unknown
    CONSTRAINT PK_DimPaymentMethod PRIMARY KEY (PaymentMethodKey)
);

CREATE TABLE dbo.DimCarrier
(
    CarrierKey       INT           NOT NULL,
    CarrierName      NVARCHAR(30)  NOT NULL,
    CarrierType      NVARCHAR(20)  NOT NULL,    -- Express / Courier / Postal / Unknown
    CONSTRAINT PK_DimCarrier PRIMARY KEY (CarrierKey)
);

CREATE TABLE dbo.DimOrderStatus
(
    OrderStatusKey   INT           NOT NULL,
    StatusName       NVARCHAR(10)  NOT NULL,
    StatusGroup      NVARCHAR(15)  NOT NULL,    -- Open / Completed / Lost sale
    IsRevenue        BIT           NOT NULL,    -- 1 = влиза в оборота
    CONSTRAINT PK_DimOrderStatus PRIMARY KEY (OrderStatusKey)
);
GO

/* =====================================================================
   ФАКТИ
   ===================================================================== */

/* Продажби – един ред за всеки ред от поръчка */
CREATE TABLE dbo.FactSales
(
    SalesKey          BIGINT IDENTITY(1,1) NOT NULL,
    OrderDateKey      INT           NOT NULL,
    BuyerKey          INT           NOT NULL,
    SellerKey         INT           NOT NULL,
    CategoryKey       INT           NOT NULL,
    ListingKey        INT           NOT NULL,
    BuyerLocationKey  INT           NOT NULL,
    PaymentMethodKey  INT           NOT NULL,
    CarrierKey        INT           NOT NULL,
    OrderStatusKey    INT           NOT NULL,
    OrderID           INT           NOT NULL,   -- дегенеративно измерение
    OrderItemID       INT           NOT NULL,
    Quantity          INT           NOT NULL,
    UnitPrice         DECIMAL(10,2) NOT NULL,
    SalesAmount       DECIMAL(12,2) NOT NULL,   -- Quantity * UnitPrice
    ShippingAmount    DECIMAL(10,2) NOT NULL,
    GrossAmount       DECIMAL(12,2) NOT NULL,   -- SalesAmount + ShippingAmount
    FinalValueFee     DECIMAL(10,2) NOT NULL,   -- комисиона на eBay (13.25%)
    DeliveryDays      DECIMAL(6,2)  NULL,
    CONSTRAINT PK_FactSales PRIMARY KEY (SalesKey),
    CONSTRAINT FK_FactSales_Date     FOREIGN KEY (OrderDateKey)     REFERENCES dbo.DimDate (DateKey),
    CONSTRAINT FK_FactSales_Buyer    FOREIGN KEY (BuyerKey)         REFERENCES dbo.DimUser (UserKey),
    CONSTRAINT FK_FactSales_Seller   FOREIGN KEY (SellerKey)        REFERENCES dbo.DimUser (UserKey),
    CONSTRAINT FK_FactSales_Category FOREIGN KEY (CategoryKey)      REFERENCES dbo.DimCategory (CategoryKey),
    CONSTRAINT FK_FactSales_Listing  FOREIGN KEY (ListingKey)       REFERENCES dbo.DimListing (ListingKey),
    CONSTRAINT FK_FactSales_Location FOREIGN KEY (BuyerLocationKey) REFERENCES dbo.DimLocation (LocationKey),
    CONSTRAINT FK_FactSales_Payment  FOREIGN KEY (PaymentMethodKey) REFERENCES dbo.DimPaymentMethod (PaymentMethodKey),
    CONSTRAINT FK_FactSales_Carrier  FOREIGN KEY (CarrierKey)       REFERENCES dbo.DimCarrier (CarrierKey),
    CONSTRAINT FK_FactSales_Status   FOREIGN KEY (OrderStatusKey)   REFERENCES dbo.DimOrderStatus (OrderStatusKey)
);

/* Наддавания – един ред за всяка оферта */
CREATE TABLE dbo.FactBids
(
    BidKey             BIGINT IDENTITY(1,1) NOT NULL,
    BidDateKey         INT           NOT NULL,
    BidderKey          INT           NOT NULL,
    SellerKey          INT           NOT NULL,
    ListingKey         INT           NOT NULL,
    CategoryKey        INT           NOT NULL,
    BidderLocationKey  INT           NOT NULL,
    BidID              INT           NOT NULL,
    BidAmount          DECIMAL(10,2) NOT NULL,
    BidSequence        INT           NOT NULL,  -- пореден номер на офертата в търга
    IncrementAmount    DECIMAL(10,2) NOT NULL,  -- разлика спрямо предходната оферта
    HoursBeforeEnd     DECIMAL(8,2)  NOT NULL,
    IsWinningBid       BIT           NOT NULL,
    CONSTRAINT PK_FactBids PRIMARY KEY (BidKey),
    CONSTRAINT FK_FactBids_Date     FOREIGN KEY (BidDateKey)        REFERENCES dbo.DimDate (DateKey),
    CONSTRAINT FK_FactBids_Bidder   FOREIGN KEY (BidderKey)         REFERENCES dbo.DimUser (UserKey),
    CONSTRAINT FK_FactBids_Seller   FOREIGN KEY (SellerKey)         REFERENCES dbo.DimUser (UserKey),
    CONSTRAINT FK_FactBids_Listing  FOREIGN KEY (ListingKey)        REFERENCES dbo.DimListing (ListingKey),
    CONSTRAINT FK_FactBids_Category FOREIGN KEY (CategoryKey)       REFERENCES dbo.DimCategory (CategoryKey),
    CONSTRAINT FK_FactBids_Location FOREIGN KEY (BidderLocationKey) REFERENCES dbo.DimLocation (LocationKey)
);

/* Оценки – един ред за всяка оценка */
CREATE TABLE dbo.FactFeedback
(
    FeedbackKey        BIGINT IDENTITY(1,1) NOT NULL,
    FeedbackDateKey    INT           NOT NULL,
    FromUserKey        INT           NOT NULL,
    ToUserKey          INT           NOT NULL,
    ListingKey         INT           NOT NULL,
    CategoryKey        INT           NOT NULL,
    FeedbackID         INT           NOT NULL,
    FeedbackRole       NVARCHAR(15)  NOT NULL,  -- Buyer->Seller / Seller->Buyer
    Rating             SMALLINT      NOT NULL,
    IsPositive         BIT           NOT NULL,
    IsNeutral          BIT           NOT NULL,
    IsNegative         BIT           NOT NULL,
    HasComment         BIT           NOT NULL,
    DaysAfterOrder     DECIMAL(6,2)  NOT NULL,
    CONSTRAINT PK_FactFeedback PRIMARY KEY (FeedbackKey),
    CONSTRAINT FK_FactFeedback_Date     FOREIGN KEY (FeedbackDateKey) REFERENCES dbo.DimDate (DateKey),
    CONSTRAINT FK_FactFeedback_From     FOREIGN KEY (FromUserKey)     REFERENCES dbo.DimUser (UserKey),
    CONSTRAINT FK_FactFeedback_To       FOREIGN KEY (ToUserKey)       REFERENCES dbo.DimUser (UserKey),
    CONSTRAINT FK_FactFeedback_Listing  FOREIGN KEY (ListingKey)      REFERENCES dbo.DimListing (ListingKey),
    CONSTRAINT FK_FactFeedback_Category FOREIGN KEY (CategoryKey)     REFERENCES dbo.DimCategory (CategoryKey)
);

/* Обяви – натрупваща моментна снимка (accumulating snapshot), 1 ред на обява */
CREATE TABLE dbo.FactListings
(
    ListingFactKey     BIGINT IDENTITY(1,1) NOT NULL,
    StartDateKey       INT           NOT NULL,
    EndDateKey         INT           NOT NULL,
    SellerKey          INT           NOT NULL,
    CategoryKey        INT           NOT NULL,
    ListingKey         INT           NOT NULL,
    SellerLocationKey  INT           NOT NULL,
    StartPrice         DECIMAL(10,2) NOT NULL,
    FinalPrice         DECIMAL(10,2) NOT NULL,
    QuantityListed     INT           NOT NULL,
    QuantitySold       INT           NOT NULL,
    BidCount           INT           NOT NULL,
    UniqueBidders      INT           NOT NULL,
    WatchCount         INT           NOT NULL,
    ViewCount          INT           NOT NULL,
    IsSold             BIT           NOT NULL,
    CONSTRAINT PK_FactListings PRIMARY KEY (ListingFactKey),
    CONSTRAINT FK_FactListings_StartDate FOREIGN KEY (StartDateKey)      REFERENCES dbo.DimDate (DateKey),
    CONSTRAINT FK_FactListings_EndDate   FOREIGN KEY (EndDateKey)        REFERENCES dbo.DimDate (DateKey),
    CONSTRAINT FK_FactListings_Seller    FOREIGN KEY (SellerKey)         REFERENCES dbo.DimUser (UserKey),
    CONSTRAINT FK_FactListings_Category  FOREIGN KEY (CategoryKey)       REFERENCES dbo.DimCategory (CategoryKey),
    CONSTRAINT FK_FactListings_Listing   FOREIGN KEY (ListingKey)        REFERENCES dbo.DimListing (ListingKey),
    CONSTRAINT FK_FactListings_Location  FOREIGN KEY (SellerLocationKey) REFERENCES dbo.DimLocation (LocationKey)
);
GO

CREATE INDEX IX_FactSales_Date     ON dbo.FactSales (OrderDateKey);
CREATE INDEX IX_FactSales_Category ON dbo.FactSales (CategoryKey);
CREATE INDEX IX_FactBids_Listing   ON dbo.FactBids (ListingKey);
CREATE INDEX IX_FactFeedback_To    ON dbo.FactFeedback (ToUserKey);
GO

PRINT N'eBayDW е създадена (8 измерения, 4 таблици факти).';
GO
