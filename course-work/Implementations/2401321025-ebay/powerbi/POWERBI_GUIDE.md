# Power BI отчет – eBay Data Warehouse

Отчетът се строи върху **eBayDW**: таблиците факти и измерения, заредени от ETL процедурата `sp_LoadDW`.
Готовият файл трябва да се запише като `powerbi/eBay_Report.pbix`.

> Нужен е **Power BI Desktop** (безплатен, от Microsoft Store) и SQL Server, на който вече са изпълнени
> скриптовете от `database/` и `datawarehouse/`.

---

## 1. Свързване към базата

1. **Home → Get data → SQL Server**.
2. Server: `localhost` (или `localhost\SQLEXPRESS`, ако ползваш Express); Database: `eBayDW`; режим **Import** → OK.
3. При автентикация избери **Windows** → *Use my current credentials* → Connect.
4. В Navigator маркирай всичките 12 таблици:
   `DimDate, DimUser, DimCategory, DimListing, DimLocation, DimPaymentMethod, DimCarrier, DimOrderStatus,
   FactSales, FactBids, FactFeedback, FactListings` → **Load**.

## 2. Модел (Model view)

Power BI може да създаде грешни връзки автоматично. Затова **изтрий всички автоматично създадени връзки**
(Model view → Manage relationships → Delete) и създай следните (всички са *Many-to-one*, *Single* филтриране):

| Факт таблица | Колона | → Измерение | Колона | Активна |
|---|---|---|---|---|
| FactSales | OrderDateKey | DimDate | DateKey | ✔ |
| FactSales | BuyerKey | DimUser | UserKey | ✔ |
| FactSales | SellerKey | DimUser | UserKey | ✖ (неактивна) |
| FactSales | CategoryKey | DimCategory | CategoryKey | ✔ |
| FactSales | ListingKey | DimListing | ListingKey | ✔ |
| FactSales | BuyerLocationKey | DimLocation | LocationKey | ✔ |
| FactSales | PaymentMethodKey | DimPaymentMethod | PaymentMethodKey | ✔ |
| FactSales | CarrierKey | DimCarrier | CarrierKey | ✔ |
| FactSales | OrderStatusKey | DimOrderStatus | OrderStatusKey | ✔ |
| FactBids | BidDateKey | DimDate | DateKey | ✔ |
| FactBids | BidderKey | DimUser | UserKey | ✔ |
| FactBids | SellerKey | DimUser | UserKey | ✖ |
| FactBids | ListingKey | DimListing | ListingKey | ✔ |
| FactBids | CategoryKey | DimCategory | CategoryKey | ✔ |
| FactBids | BidderLocationKey | DimLocation | LocationKey | ✔ |
| FactFeedback | FeedbackDateKey | DimDate | DateKey | ✔ |
| FactFeedback | ToUserKey | DimUser | UserKey | ✔ |
| FactFeedback | FromUserKey | DimUser | UserKey | ✖ |
| FactFeedback | ListingKey | DimListing | ListingKey | ✔ |
| FactFeedback | CategoryKey | DimCategory | CategoryKey | ✔ |
| FactListings | StartDateKey | DimDate | DateKey | ✔ |
| FactListings | EndDateKey | DimDate | DateKey | ✖ |
| FactListings | SellerKey | DimUser | UserKey | ✔ |
| FactListings | CategoryKey | DimCategory | CategoryKey | ✔ |
| FactListings | ListingKey | DimListing | ListingKey | ✔ |
| FactListings | SellerLocationKey | DimLocation | LocationKey | ✔ |

Неактивните връзки (role-playing) се използват в мерките чрез `USERELATIONSHIP`.

**Таблица с дати:** избери `DimDate` → *Table tools* → **Mark as date table** → колона `FullDate`.
**Сортиране:** `DimDate[MonthName]` → *Sort by column* → `MonthNumber`.
**Категории данни:** `DimLocation[Country]` → *Data category* → **Country/Region**, `DimLocation[City]` → **City**.

## 3. Мерки

Отвори `measures.dax` и създай всяка мярка с **Home → New measure** (копирай една по една).
Препоръчително: сложи мерките в отделна празна таблица *Measures* (Home → Enter data → Load).

Форматиране: `Revenue`, `Average Order Value`, `Seller Revenue`, `eBay Fees` → Currency ($);
мерките с `%` в името → Percentage.

## 4. Визуализации

### Страница 1 – „Продажби“ (Sales Overview)

| # | Визуализация | Полета |
|---|---|---|
| 1 | **Card** ×4 (KPI ред) | `Revenue`, `Orders`, `Average Order Value`, `Items Sold` |
| 2 | **Line chart** – оборот по месеци | X: `DimDate[YearMonth]`, Y: `Revenue` |
| 3 | **Clustered bar chart** – оборот по категория | Y: `DimCategory[MainCategoryName]`, X: `Revenue` |
| 4 | **Filled map** (или Map) – оборот по държава на купувача | Location: `DimLocation[Country]`, Color/Size: `Revenue` |
| 5 | **Donut chart** – методи на плащане | Legend: `DimPaymentMethod[PaymentMethod]`, Values: `Revenue` |
| 6 | **Slicer** ×2 | `DimDate[Year]`, `DimLocation[Region]` |

### Страница 2 – „Търгове и продавачи“ (Auctions & Sellers)

| # | Визуализация | Полета |
|---|---|---|
| 7 | **Clustered column chart** – наддавания на търг | X: `DimCategory[MainCategoryName]`, Y: `Avg Bids per Auction` |
| 8 | **Table** – топ продавачи | `DimUser[Username]`, `DimUser[SellerTier]`, `Seller Revenue`, `DimUser[PositivePercent]`; филтър `DimUser[IsSeller] = True`; сортиране по `Seller Revenue` ↓ |
| 9 | **Stacked bar chart** – оценки | Y: `DimCategory[MainCategoryName]`, X: `Feedback Count`, Legend: `FactFeedback[Rating]` |
| 10 | **Gauge** – Sell-through | Value: `Sell-Through Rate %`, Max: 1 |
| 11 | **Card** | `Positive Feedback %`, `Auction Price Multiplier` |

> Минималното изискване е 3 визуализации. Двете страници съдържат 11 визуализации, което е допълнение към заданието.

## 5. Контролни стойности (за проверка)

Ако базата е заредена само с `03_seed_data.sql` (без `04_demo_queries.sql` преди ETL), без филтри:

| Мярка | Очаквана стойност |
|---|---|
| Revenue | ≈ **326 962** |
| Orders | **734** |
| Items Sold | **827** |
| Average Order Value | ≈ **445.45** |
| Revenue 2024 / 2025 / 2026 | ≈ 76 954 / 98 386 / 151 622 |
| Bids | **1 349** |
| Auctions With Bids | **200** |

## 6. Запис и публикуване

1. **File → Save as** → `course-work/implementations/2401321025-ebay/powerbi/eBay_Report.pbix`.
2. По желание: **File → Export → Export to PDF** → `powerbi/eBay_Report.pdf`. Така отчетът се вижда и без Power BI.
3. Направи screenshot на двете страници и ги запиши като `powerbi/page1_sales.png` и `powerbi/page2_auctions.png`.
   README-то вече има връзки към тях.
