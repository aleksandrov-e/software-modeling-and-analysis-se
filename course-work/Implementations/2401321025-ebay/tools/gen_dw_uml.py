"""Физически модел на Data Warehouse (UML database notation) -> diagrams/03_datawarehouse_uml.drawio + .svg"""
import os
from diagram_lib import Diagram

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "diagrams")
d = Diagram("Data Warehouse (UML)", 1620, 1770)
d.text(40, 16, 1300, 36, "eBayDW – физически модел на Data Warehouse (UML database notation)", size=24, bold=True, align="left")
d.text(40, 52, 1500, 24, "Емил Александров, ф.н. 2401321025  |  схема „съзвездие“: 4 таблици факти (оранжево) и "
       "8 таблици измерения (синьо)", size=13, color="#555555", align="left")

FACT, FACT_S = "#ffe6cc", "#d79b00"
DIM, DIM_S = "#dae8fc", "#6c8ebf"


def fact(x, y, name, rows):
    return d.table(x, y, 300, name, rows, header=FACT, stroke=FACT_S, stereotype="fact table", key_w=40)


def dim(x, y, name, rows, w=280):
    return d.table(x, y, w, name, rows, header=DIM, stroke=DIM_S, stereotype="dimension", key_w=40)


# ------------------------------------------------------------------ измерения само за продажбите (вляво горе)
PAYM = dim(40, 130, "DimPaymentMethod", [("PK", "PaymentMethodKey", "INT"), ("", "PaymentMethod", "NVARCHAR(20)"),
                                          ("", "PaymentType", "NVARCHAR(20)")], w=270)
CARR = dim(40, 290, "DimCarrier", [("PK", "CarrierKey", "INT"), ("", "CarrierName", "NVARCHAR(30)"),
                                    ("", "CarrierType", "NVARCHAR(20)")], w=270)
STAT = dim(40, 450, "DimOrderStatus", [("PK", "OrderStatusKey", "INT"), ("", "StatusName", "NVARCHAR(10)"),
                                        ("", "StatusGroup", "NVARCHAR(15)"), ("", "IsRevenue", "BIT")], w=270)

# ------------------------------------------------------------------ факти (горе)
SALES = fact(400, 130, "FactSales", [
    ("PK", "SalesKey", "BIGINT"), ("FK", "OrderDateKey", "INT"), ("FK", "BuyerKey", "INT"), ("FK", "SellerKey", "INT"),
    ("FK", "CategoryKey", "INT"), ("FK", "ListingKey", "INT"), ("FK", "BuyerLocationKey", "INT"),
    ("FK", "PaymentMethodKey", "INT"), ("FK", "CarrierKey", "INT"), ("FK", "OrderStatusKey", "INT"),
    ("", "OrderID", "INT"), ("", "OrderItemID", "INT"), ("", "Quantity", "INT"), ("", "UnitPrice", "DECIMAL(10,2)"),
    ("", "SalesAmount", "DECIMAL(12,2)"), ("", "ShippingAmount", "DECIMAL(10,2)"), ("", "GrossAmount", "DECIMAL(12,2)"),
    ("", "FinalValueFee", "DECIMAL(10,2)"), ("", "DeliveryDays", "DECIMAL(6,2)")])
BIDS = fact(1060, 130, "FactBids", [
    ("PK", "BidKey", "BIGINT"), ("FK", "BidDateKey", "INT"), ("FK", "BidderKey", "INT"), ("FK", "SellerKey", "INT"),
    ("FK", "ListingKey", "INT"), ("FK", "CategoryKey", "INT"), ("FK", "BidderLocationKey", "INT"),
    ("", "BidID", "INT"), ("", "BidAmount", "DECIMAL(10,2)"), ("", "BidSequence", "INT"),
    ("", "IncrementAmount", "DECIMAL(10,2)"), ("", "HoursBeforeEnd", "DECIMAL(8,2)"), ("", "IsWinningBid", "BIT")])

# ------------------------------------------------------------------ общи измерения (среден ред)
Y = 790
DATE = dim(40, Y, "DimDate", [
    ("PK", "DateKey", "INT"), ("", "FullDate", "DATE"), ("", "DayOfMonth", "TINYINT"), ("", "DayOfWeek", "TINYINT"),
    ("", "DayName", "NVARCHAR(10)"), ("", "IsWeekend", "BIT"), ("", "WeekOfYear", "TINYINT"),
    ("", "MonthNumber", "TINYINT"), ("", "MonthName", "NVARCHAR(10)"), ("", "Quarter", "TINYINT"),
    ("", "QuarterName", "CHAR(2)"), ("", "Year", "SMALLINT"), ("", "YearMonth", "CHAR(7)")])
USER = dim(355, Y, "DimUser", [
    ("PK", "UserKey", "INT"), ("", "UserID", "INT"), ("", "Username", "NVARCHAR(50)"), ("", "FullName", "NVARCHAR(101)"),
    ("", "Country", "NVARCHAR(60)"), ("", "City", "NVARCHAR(60)"), ("", "IsSeller", "BIT"), ("", "IsActive", "BIT"),
    ("", "RegistrationDate", "DATE"), ("", "RegistrationYear", "SMALLINT"), ("", "FeedbackScore", "INT"),
    ("", "PositivePercent", "DECIMAL(5,2)"), ("", "SellerTier", "NVARCHAR(20)")])
CAT = dim(670, Y, "DimCategory", [
    ("PK", "CategoryKey", "INT"), ("", "CategoryID", "INT"), ("", "CategoryName", "NVARCHAR(100)"),
    ("", "MainCategoryID", "INT"), ("", "MainCategoryName", "NVARCHAR(100)")])
LIST = dim(985, Y, "DimListing", [
    ("PK", "ListingKey", "INT"), ("", "ListingID", "INT"), ("", "Title", "NVARCHAR(150)"),
    ("", "ListingFormat", "NVARCHAR(10)"), ("", "ItemCondition", "NVARCHAR(20)"), ("", "HasBuyItNow", "BIT"),
    ("", "ListingStatus", "NVARCHAR(10)"), ("", "DurationDays", "INT"), ("", "PriceBand", "NVARCHAR(20)")])
LOC = dim(1300, Y, "DimLocation", [
    ("PK", "LocationKey", "INT"), ("", "Country", "NVARCHAR(60)"), ("", "City", "NVARCHAR(60)"),
    ("", "Region", "NVARCHAR(30)"), ("", "IsEU", "BIT")])

# ------------------------------------------------------------------ факти (долу)
YB = 1330
FEED = fact(240, YB, "FactFeedback", [
    ("PK", "FeedbackKey", "BIGINT"), ("FK", "FeedbackDateKey", "INT"), ("FK", "FromUserKey", "INT"),
    ("FK", "ToUserKey", "INT"), ("FK", "ListingKey", "INT"), ("FK", "CategoryKey", "INT"), ("", "FeedbackID", "INT"),
    ("", "FeedbackRole", "NVARCHAR(15)"), ("", "Rating", "SMALLINT"), ("", "IsPositive", "BIT"), ("", "IsNeutral", "BIT"),
    ("", "IsNegative", "BIT"), ("", "HasComment", "BIT"), ("", "DaysAfterOrder", "DECIMAL(6,2)")])
LSTF = fact(960, YB, "FactListings", [
    ("PK", "ListingFactKey", "BIGINT"), ("FK", "StartDateKey", "INT"), ("FK", "EndDateKey", "INT"),
    ("FK", "SellerKey", "INT"), ("FK", "CategoryKey", "INT"), ("FK", "ListingKey", "INT"),
    ("FK", "SellerLocationKey", "INT"), ("", "StartPrice", "DECIMAL(10,2)"), ("", "FinalPrice", "DECIMAL(10,2)"),
    ("", "QuantityListed", "INT"), ("", "QuantitySold", "INT"), ("", "BidCount", "INT"), ("", "UniqueBidders", "INT"),
    ("", "WatchCount", "INT"), ("", "ViewCount", "INT"), ("", "IsSold", "BIT")])


def bottom(cid):
    x, y, w, h = d.geom[cid]
    return y + h


# ------------------------------------------------------------------ връзки
def down(src, sx, dst, dx, yc, role=None):
    """факт (горе) -> измерение (среден ред)"""
    y0 = bottom(src)
    labels = [("*", -1, 9, 12), ("1", 1, 9, -10)]
    if role:
        labels.append((role, 1, 0, -26))
    d.poly_edge([(sx, y0), (sx, yc), (dx, yc), (dx, Y)], src, dst, labels=labels, color="#666666")


def up(src, sx, dst, dx, yc, role=None):
    """факт (долу) -> измерение (среден ред)"""
    y1 = bottom(dst)
    labels = [("*", -1, 9, -12), ("1", 1, 9, 12)]
    if role:
        labels.append((role, 1, -26, 20))
    d.poly_edge([(sx, YB), (sx, yc), (dx, yc), (dx, y1)], src, dst, labels=labels, color="#666666")


def side(src_dim, dst_fact, y):
    x, _, w, _ = d.geom[src_dim]
    fx = d.geom[dst_fact][0]
    d.poly_edge([(fx, y), (x + w, y)], dst_fact, src_dim, labels=[("*", -1, -10, -10), ("1", 1, 10, -10)], color="#666666")


side(PAYM, SALES, 188); side(CARR, SALES, 348); side(STAT, SALES, 518)

# FactSales -> общите измерения (канал между y=bottom(SALES) и Y)
down(SALES, 420, DATE, 200, 640)
down(SALES, 450, USER, 420, 655, "Buyer")
down(SALES, 480, USER, 560, 670, "Seller")
down(SALES, 540, CAT, 760, 685)
down(SALES, 600, LIST, 1060, 700)
down(SALES, 660, LOC, 1360, 715)
# FactBids
down(BIDS, 1080, DATE, 240, 740)
down(BIDS, 1110, USER, 470, 755, "Bidder")
down(BIDS, 1140, USER, 610, 770, "Seller")
down(BIDS, 1200, CAT, 820, 725)
down(BIDS, 1260, LIST, 1110, 690)
down(BIDS, 1330, LOC, 1440, 655)

# FactFeedback -> измерения (канал между долния край на измеренията и YB)
up(FEED, 270, DATE, 180, 1250)
up(FEED, 320, USER, 430, 1263, "From")
up(FEED, 380, USER, 590, 1276, "To")
up(FEED, 450, LIST, 1030, 1302)
up(FEED, 510, CAT, 740, 1289)
# FactListings
up(LSTF, 980, DATE, 120, 1170, "Start")
up(LSTF, 1010, DATE, 260, 1183, "End")
up(LSTF, 1060, USER, 520, 1196, "Seller")
up(LSTF, 1120, CAT, 860, 1209)
up(LSTF, 1180, LIST, 1170, 1222)
up(LSTF, 1240, LOC, 1400, 1235)

# легенда
d.text(1320, 1310, 280, 22, "Легенда (UML)", size=14, bold=True, align="left")
d.text(1320, 1338, 290, 20, "«fact table» – таблица факти", size=12, align="left")
d.text(1320, 1360, 290, 20, "«dimension» – таблица измерение", size=12, align="left")
d.text(1320, 1382, 290, 20, "PK – първичен (сурогатен) ключ", size=12, align="left")
d.text(1320, 1404, 290, 20, "FK – външен ключ към измерение", size=12, align="left")
d.text(1320, 1426, 290, 20, "1 … * – множественост на асоциацията", size=12, align="left")
d.text(1320, 1448, 290, 20, "Buyer/Seller/From/To – роли на DimUser", size=12, align="left")
d.text(1320, 1470, 290, 20, "Start/End – роли на DimDate", size=12, align="left")

base = os.path.join(OUT, "03_datawarehouse_uml")
d.save(base + ".drawio", base + ".svg")
print("ok", bottom(SALES), bottom(BIDS), bottom(DATE), bottom(USER), bottom(LIST), bottom(FEED), bottom(LSTF))
