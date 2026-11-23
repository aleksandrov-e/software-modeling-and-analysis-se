"""Логически модел (Crow's Foot) -> diagrams/02_logical_crowsfoot.drawio + .svg"""
import os
from diagram_lib import Diagram

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "diagrams")
d = Diagram("Logical model (Crow's Foot)", 1620, 1200)
d.text(40, 16, 1200, 36, "eBay – логически модел (Crow's Foot notation)", size=24, bold=True, align="left")
d.text(40, 52, 1500, 24, "Емил Александров, ф.н. 2401321025  |  10 таблици, 78 атрибута, M:N връзки: "
       "Users–Listings (Bids, Watchlist), Orders–Listings (OrderItems)", size=13, color="#555555", align="left")

W = 260
BLUE, BLUE_S = "#dae8fc", "#6c8ebf"
GREEN, GREEN_S = "#d5e8d4", "#82b366"     # свързващи (junction) таблици

USERS = d.table(60, 140, W, "Users", [
    ("PK", "UserID", "INT"), ("UQ", "Username", "NVARCHAR(50)"), ("UQ", "Email", "NVARCHAR(100)"),
    ("", "PasswordHash", "NVARCHAR(256)"), ("", "FirstName", "NVARCHAR(50)"), ("", "LastName", "NVARCHAR(50)"),
    ("", "Phone", "NVARCHAR(30)"), ("", "Country", "NVARCHAR(60)"), ("", "City", "NVARCHAR(60)"),
    ("", "RegistrationDate", "DATETIME2"), ("", "IsSeller", "BIT"), ("", "FeedbackScore", "INT"),
    ("", "IsActive", "BIT")])
BIDS = d.table(440, 140, W, "Bids", [
    ("PK", "BidID", "INT"), ("FK", "ListingID", "INT"), ("FK", "BidderID", "INT"),
    ("", "BidAmount", "DECIMAL(10,2)"), ("", "BidTime", "DATETIME2")], header=GREEN, stroke=GREEN_S)
WATCH = d.table(440, 360, W, "Watchlist", [
    ("PK,FK", "UserID", "INT"), ("PK,FK", "ListingID", "INT"), ("", "AddedDate", "DATETIME2")],
    header=GREEN, stroke=GREEN_S, key_w=46)
LISTINGS = d.table(820, 140, W, "Listings", [
    ("PK", "ListingID", "INT"), ("FK", "SellerID", "INT"), ("FK", "CategoryID", "INT"),
    ("", "Title", "NVARCHAR(150)"), ("", "Description", "NVARCHAR(MAX)"), ("", "ItemCondition", "NVARCHAR(20)"),
    ("", "ListingFormat", "NVARCHAR(10)"), ("", "StartPrice", "DECIMAL(10,2)"), ("", "BuyItNowPrice", "DECIMAL(10,2)"),
    ("", "CurrentPrice", "DECIMAL(10,2)"), ("", "Quantity", "INT"), ("", "QuantitySold", "INT"),
    ("", "ShippingCost", "DECIMAL(8,2)"), ("", "StartDate", "DATETIME2"), ("", "EndDate", "DATETIME2"),
    ("", "Status", "NVARCHAR(10)"), ("", "ViewCount", "INT")])
CATS = d.table(1200, 140, W, "Categories", [
    ("PK", "CategoryID", "INT"), ("FK", "ParentCategoryID", "INT"), ("", "Name", "NVARCHAR(100)"),
    ("", "Description", "NVARCHAR(400)"), ("", "IsActive", "BIT")])
ORDERS = d.table(60, 640, W, "Orders", [
    ("PK", "OrderID", "INT"), ("FK", "BuyerID", "INT"), ("", "OrderDate", "DATETIME2"),
    ("", "Status", "NVARCHAR(10)"), ("", "ShippingAddress", "NVARCHAR(200)"), ("", "ShippingCity", "NVARCHAR(60)"),
    ("", "ShippingCountry", "NVARCHAR(60)"), ("", "TotalAmount", "DECIMAL(12,2)")])
ITEMS = d.table(440, 640, W, "OrderItems", [
    ("PK", "OrderItemID", "INT"), ("FK", "OrderID", "INT"), ("FK", "ListingID", "INT"),
    ("", "Quantity", "INT"), ("", "UnitPrice", "DECIMAL(10,2)"), ("", "ShippingCost", "DECIMAL(8,2)")],
    header=GREEN, stroke=GREEN_S)
FEED = d.table(820, 680, W, "Feedback", [
    ("PK", "FeedbackID", "INT"), ("FK", "OrderItemID", "INT"), ("FK", "FromUserID", "INT"),
    ("FK", "ToUserID", "INT"), ("", "Rating", "SMALLINT"), ("", "Comment", "NVARCHAR(500)"),
    ("", "CreatedAt", "DATETIME2")])
PAY = d.table(60, 960, W, "Payments", [
    ("PK", "PaymentID", "INT"), ("FK", "OrderID", "INT"), ("", "PaymentMethod", "NVARCHAR(20)"),
    ("", "Amount", "DECIMAL(12,2)"), ("", "PaymentDate", "DATETIME2"), ("", "Status", "NVARCHAR(10)"),
    ("UQ", "TransactionRef", "NVARCHAR(40)")])
SHIP = d.table(440, 960, W, "Shipments", [
    ("PK", "ShipmentID", "INT"), ("FK,UQ", "OrderID", "INT"), ("", "Carrier", "NVARCHAR(30)"),
    ("UQ", "TrackingNumber", "NVARCHAR(40)"), ("", "ShippedDate", "DATETIME2"), ("", "DeliveredDate", "DATETIME2"),
    ("", "ShippingStatus", "NVARCHAR(12)")], key_w=46)

# --------------------------------------------------------------------- връзки (родител = ||, дете = o< / |<)
E = d.poly_edge
E([(320, 239), (440, 239)], USERS, BIDS, "mone", "zmany")                       # Users 1 - 0..* Bids
E([(820, 217), (700, 217)], LISTINGS, BIDS, "mone", "zmany")                    # Listings 1 - 0..* Bids
E([(320, 427), (440, 427)], USERS, WATCH, "mone", "zmany")                      # Users 1 - 0..* Watchlist
E([(820, 427), (700, 427)], LISTINGS, WATCH, "mone", "zmany")                   # Listings 1 - 0..* Watchlist
E([(190, 140), (190, 108), (950, 108), (950, 140)], USERS, LISTINGS, "mone", "zmany")   # Users 1 - 0..* Listings
E([(1200, 239), (1080, 239)], CATS, LISTINGS, "mone", "zmany")                  # Categories 1 - 0..* Listings
E([(1460, 195), (1510, 195), (1510, 262), (1460, 262)], CATS, CATS, "zone", "zmany")    # родител 0..1 - 0..* деца
E([(130, 460), (130, 640)], USERS, ORDERS, "mone", "zmany")                     # Users 1 - 0..* Orders
E([(320, 720), (440, 720)], ORDERS, ITEMS, "mone", "omany")                     # Orders 1 - 1..* OrderItems
E([(820, 500), (760, 500), (760, 683), (700, 683)], LISTINGS, ITEMS, "mone", "zmany")  # Listings 1 - 0..* OrderItems
E([(700, 760), (820, 760)], ITEMS, FEED, "mone", "zmany")                       # OrderItems 1 - 0..* Feedback
E([(230, 460), (230, 590), (1000, 590), (1000, 680)], USERS, FEED, "mone", "zmany", dashed=False)   # FromUser
E([(270, 460), (270, 610), (1040, 610), (1040, 680)], USERS, FEED, "mone", "zmany")   # ToUser
E([(130, 850), (130, 960)], ORDERS, PAY, "mone", "zmany")                       # Orders 1 - 0..* Payments
E([(260, 850), (260, 905), (520, 905), (520, 960)], ORDERS, SHIP, "mone", "zone")   # Orders 1 - 0..1 Shipments

d.text(1012, 588, 120, 20, "FromUserID", size=10, color="#777777", italic=True, align="left")
d.text(1052, 618, 120, 20, "ToUserID", size=10, color="#777777", italic=True, align="left")
d.text(1515, 215, 110, 20, "ParentCategoryID", size=10, color="#777777", italic=True, align="left")

# легенда
lx, ly = 1200, 960
d.text(lx, ly, 380, 24, "Легенда", size=14, bold=True, align="left")
d.poly_edge([(lx, ly + 40), (lx + 70, ly + 40)], end="mone");  d.text(lx + 85, ly + 30, 300, 20, "точно едно (1)", size=12, align="left")
d.poly_edge([(lx, ly + 70), (lx + 70, ly + 70)], end="zone");  d.text(lx + 85, ly + 60, 300, 20, "нула или едно (0..1)", size=12, align="left")
d.poly_edge([(lx, ly + 100), (lx + 70, ly + 100)], end="zmany"); d.text(lx + 85, ly + 90, 300, 20, "нула или много (0..*)", size=12, align="left")
d.poly_edge([(lx, ly + 130), (lx + 70, ly + 130)], end="omany"); d.text(lx + 85, ly + 120, 300, 20, "едно или много (1..*)", size=12, align="left")
d.text(lx, ly + 150, 380, 22, "зелено = свързваща таблица (M:N)", size=12, color="#4d7a3a", align="left")
d.text(lx, ly + 172, 380, 22, "PK първичен, FK външен, UQ уникален ключ", size=12, color="#555555", align="left")

base = os.path.join(OUT, "02_logical_crowsfoot")
d.save(base + ".drawio", base + ".svg")
print("ok")
