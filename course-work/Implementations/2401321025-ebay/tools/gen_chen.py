"""Концептуален модел (Chen's notation) -> diagrams/01_conceptual_chen.drawio + .svg"""
import math
import os
from diagram_lib import Diagram

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "diagrams")
d = Diagram("Conceptual model (Chen)", 3300, 2750)
d.text(40, 20, 1400, 40, "eBay – концептуален модел (Chen's notation)", size=26, bold=True, align="left")
d.text(40, 60, 1400, 26, "Емил Александров, ф.н. 2401321025  |  правоъгълник = същност, ромб = връзка, "
       "елипса = атрибут (подчертан = ключ), ромб в правоъгълник = асоциативна същност",
       size=14, color="#555555", align="left")

EW, EH = 180, 58


def entity(cx, cy, name, assoc=False):
    return d.rect(cx - EW / 2, cy - EH / 2, EW, EH, name, double=assoc,
                  fill="#e1d5e7" if assoc else "#dae8fc", stroke="#9673a6" if assoc else "#6c8ebf")


def fan(owner, cx, cy, attrs, a0, a1, rings=(230, 380), keys=("",)):
    """Разполага атрибутите в дъга [a0, a1] (градуси, 0 = надясно, 90 = надолу) на редуващи се радиуси."""
    n = len(attrs)
    for i, a in enumerate(attrs):
        ang = math.radians(a0 + (a1 - a0) * (i / (n - 1) if n > 1 else .5))
        r = rings[i % len(rings)]
        ax, ay = cx + r * math.cos(ang), cy + r * math.sin(ang)
        aid = d.ellipse(round(ax), round(ay), a, key=a in keys)
        d.line(owner, aid, width=1)


# ---------------------------------------------------------------- същности
U = (1150, 860);  USER = entity(*U, "USER")
L = (2200, 860);  LISTING = entity(*L, "LISTING")
C = (2980, 1250); CATEGORY = entity(*C, "CATEGORY")
O = (1150, 1820); ORDER = entity(*O, "ORDER")
OI = (2200, 1820); ITEM = entity(*OI, "ORDER_ITEM", assoc=True)
F = (1700, 1400); FEEDBACK = entity(*F, "FEEDBACK")
P = (700, 2420);  PAYMENT = entity(*P, "PAYMENT")
S = (1600, 2420); SHIPMENT = entity(*S, "SHIPMENT")

# ---------------------------------------------------------------- атрибути
fan(USER, *U, ["UserID", "Username", "Email", "PasswordHash", "FirstName", "LastName", "Phone",
               "Country", "City", "RegistrationDate", "IsSeller", "FeedbackScore", "IsActive"],
    115, 255, rings=(270, 450), keys=("UserID",))
fan(LISTING, *L, ["Title", "Description", "ItemCondition", "ListingFormat", "StartPrice",
                  "BuyItNowPrice", "CurrentPrice", "Quantity", "QuantitySold", "ShippingCost", "StartDate",
                  "EndDate", "Status", "ViewCount", "ListingID"],
    224, 358, rings=(300, 500), keys=("ListingID",))
fan(CATEGORY, *C, ["CategoryID", "Name", "Description", "IsActive"], -75, 30, rings=(220,), keys=("CategoryID",))
fan(ORDER, *O, ["OrderID", "OrderDate", "Status", "ShippingAddress", "ShippingCity", "ShippingCountry",
                "TotalAmount"], 150, 250, rings=(260, 400), keys=("OrderID",))
fan(ITEM, *OI, ["OrderItemID", "Quantity", "UnitPrice", "ShippingCost"], 330, 420, rings=(230,), keys=("OrderItemID",))
fan(FEEDBACK, *F, ["FeedbackID", "Rating", "Comment", "CreatedAt"], 80, 172, rings=(200,), keys=("FeedbackID",))
fan(PAYMENT, *P, ["PaymentID", "PaymentMethod", "Amount", "PaymentDate", "Status", "TransactionRef"],
    100, 220, rings=(200, 300), keys=("PaymentID",))
fan(SHIPMENT, *S, ["ShipmentID", "Carrier", "TrackingNumber", "ShippedDate", "DeliveredDate", "ShippingStatus"],
    -40, 80, rings=(210, 310), keys=("ShipmentID",))

# ---------------------------------------------------------------- връзки
def rel(cx, cy, name, a, b, la, lb, w=150):
    r = d.diamond(cx, cy, name, w=w)
    d.line(a, r, la, label_pos=.35)
    d.line(r, b, lb, label_pos=.65)
    return r


SELLS = rel(1680, 860, "SELLS", USER, LISTING, "1", "N")
BIDS = rel(1680, 620, "BIDS_ON", USER, LISTING, "M", "N")
for i, a in enumerate(["BidID", "BidAmount", "BidTime"]):
    aid = d.ellipse(1530 + i * 150, 470 + (25 if i != 1 else 0), a, key=a == "BidID")
    d.line(BIDS, aid, width=1)
WATCH = rel(1680, 1100, "WATCHES", USER, LISTING, "M", "N")
aid = d.ellipse(1900, 1170, "AddedDate"); d.line(WATCH, aid, width=1)

rel(2620, 1050, "BELONGS_TO", LISTING, CATEGORY, "N", "1", w=160)

# рекурсивна връзка SUBCATEGORY_OF (родител 1 : N подкатегории)
SUB = d.diamond(2980, 1560, "SUBCATEGORY_OF", w=190)
d.poly_edge([(2935, 1279), (2935, 1560), (2885, 1560)], src=CATEGORY, dst=SUB)
d.poly_edge([(3025, 1279), (3025, 1560), (3075, 1560)], src=CATEGORY, dst=SUB)
d.text(2885, 1300, 50, 24, "1", size=13, bold=True, color="#c0392b")
d.text(3030, 1300, 50, 24, "N", size=13, bold=True, color="#c0392b")
d.text(2870, 1610, 220, 22, "(родител – подкатегория)", size=11, color="#777777", italic=True)

rel(1150, 1340, "PLACES", USER, ORDER, "1", "N")
rel(1420, 1090, "GIVES", USER, FEEDBACK, "1", "N", w=120)
rel(1390, 1250, "RECEIVES", USER, FEEDBACK, "1", "N", w=130)
rel(1950, 1610, "RATES", ITEM, FEEDBACK, "1", "N", w=120)

# асоциативна същност ORDER_ITEM = връзката CONTAINS между ORDER и LISTING (M:N)
d.line(ORDER, ITEM, "M", label_pos=.15)
d.line(LISTING, ITEM, "N", label_pos=.82)
d.text(1560, 1830, 280, 24, "CONTAINS (M:N)", size=12, bold=True, color="#9673a6")

rel(930, 2120, "PAID_BY", ORDER, PAYMENT, "1", "N", w=130)
rel(1380, 2120, "SHIPPED_BY", ORDER, SHIPMENT, "1", "1", w=150)

base = os.path.join(OUT, "01_conceptual_chen")
d.save(base + ".drawio", base + ".svg")
print("ok", base)
