"""
Генератор на тестови данни за eBayDB (курсова работа, ф.н. 2401321025).

Създава ../database/03_seed_data.sql с консистентни данни:
потребители, категории, обяви (търгове и „Купи сега“), наддавания,
следени обяви, поръчки (вкл. многоредови), плащания, доставки и оценки.

Стартиране:  python generate_seed.py
Резултатът е детерминиран (фиксиран random seed).
"""
import hashlib
import os
import random
from datetime import datetime, timedelta

random.seed(2401321025)

NOW = datetime(2026, 11, 23, 12, 0, 0)          # „днешна дата“ за данните
START = datetime(2024, 1, 1)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "database", "03_seed_data.sql")

# ---------------------------------------------------------------------------
# Помощни функции
# ---------------------------------------------------------------------------
def q(v):
    """SQL литерал."""
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, (int,)):
        return str(v)
    if isinstance(v, float):
        return f"{v:.2f}"
    if isinstance(v, datetime):
        return "'" + v.strftime("%Y-%m-%dT%H:%M:%S") + "'"
    return "N'" + str(v).replace("'", "''") + "'"


def rand_dt(a, b):
    sec = int((b - a).total_seconds())
    return a + timedelta(seconds=random.randint(0, max(sec, 0)))


def money(x):
    return round(x + 1e-9, 2)


def bid_increment(p):
    for limit, inc in [(1, .05), (5, .25), (25, .5), (100, 1), (250, 2.5), (500, 5),
                       (1000, 10), (2500, 25), (5000, 50)]:
        if p < limit:
            return inc
    return 100


# ---------------------------------------------------------------------------
# Потребители
# ---------------------------------------------------------------------------
LOCATIONS = {
    "Bulgaria":       ["Sofia", "Plovdiv", "Varna", "Burgas", "Blagoevgrad", "Gotse Delchev", "Ruse"],
    "United States":  ["New York", "Los Angeles", "Chicago", "Houston", "Seattle", "Miami"],
    "United Kingdom": ["London", "Manchester", "Birmingham", "Leeds"],
    "Germany":        ["Berlin", "Munich", "Hamburg", "Cologne"],
    "France":         ["Paris", "Lyon", "Marseille"],
    "Italy":          ["Rome", "Milan", "Naples"],
    "Spain":          ["Madrid", "Barcelona", "Valencia"],
    "Canada":         ["Toronto", "Vancouver", "Montreal"],
    "Australia":      ["Sydney", "Melbourne"],
    "Netherlands":    ["Amsterdam", "Rotterdam"],
    "Poland":         ["Warsaw", "Krakow"],
    "Greece":         ["Athens", "Thessaloniki"],
    "Japan":          ["Tokyo", "Osaka"],
}
COUNTRY_WEIGHTS = {"Bulgaria": 16, "United States": 20, "United Kingdom": 11, "Germany": 10, "France": 6,
                   "Italy": 6, "Spain": 5, "Canada": 5, "Australia": 4, "Netherlands": 4, "Poland": 4,
                   "Greece": 3, "Japan": 3}
PHONE_PREFIX = {"Bulgaria": "+359 88", "United States": "+1 212", "United Kingdom": "+44 20", "Germany": "+49 30",
                "France": "+33 1", "Italy": "+39 06", "Spain": "+34 91", "Canada": "+1 416", "Australia": "+61 2",
                "Netherlands": "+31 20", "Poland": "+48 22", "Greece": "+30 21", "Japan": "+81 3"}
NAMES = {
    "Bulgaria": (["Georgi", "Ivan", "Dimitar", "Nikolay", "Maria", "Elena", "Petya", "Aleksandar", "Viktoria", "Kristiyan", "Yana", "Stoyan"],
                 ["Ivanov", "Georgieva", "Petrov", "Dimitrova", "Stoyanov", "Nikolova", "Kolev", "Todorova", "Angelov", "Hristova"]),
    "United States": (["James", "Emily", "Michael", "Olivia", "David", "Sophia", "Daniel", "Ava", "Chris", "Megan"],
                      ["Smith", "Johnson", "Brown", "Miller", "Davis", "Wilson", "Moore", "Taylor", "Clark", "Lewis"]),
    "United Kingdom": (["Oliver", "Amelia", "Harry", "Isla", "George", "Grace", "Jack", "Lily"],
                       ["Walker", "Wright", "Evans", "Hughes", "Turner", "Wood", "Hall", "Green"]),
    "Germany": (["Lukas", "Anna", "Felix", "Lena", "Jonas", "Hannah", "Paul", "Laura"],
                ["Muller", "Schmidt", "Schneider", "Fischer", "Weber", "Wagner", "Becker", "Hoffmann"]),
    "France": (["Louis", "Chloe", "Hugo", "Manon", "Lucas", "Camille"], ["Martin", "Bernard", "Dubois", "Moreau", "Laurent"]),
    "Italy": (["Marco", "Giulia", "Luca", "Sofia", "Matteo", "Chiara"], ["Rossi", "Russo", "Ferrari", "Esposito", "Bianchi"]),
    "Spain": (["Pablo", "Lucia", "Alejandro", "Paula", "Javier"], ["Garcia", "Fernandez", "Lopez", "Martinez", "Sanchez"]),
    "Canada": (["Liam", "Emma", "Noah", "Charlotte", "Ethan"], ["Tremblay", "Roy", "Gagnon", "Campbell", "Anderson"]),
    "Australia": (["Jack", "Mia", "Thomas", "Chloe", "Cooper"], ["Jones", "Williams", "Thompson", "White", "Kelly"]),
    "Netherlands": (["Daan", "Emma", "Sem", "Julia", "Lars"], ["de Jong", "Jansen", "de Vries", "Bakker", "Visser"]),
    "Poland": (["Jakub", "Zuzanna", "Kacper", "Julia", "Szymon"], ["Nowak", "Kowalski", "Wisniewski", "Wojcik", "Kaminski"]),
    "Greece": (["Giorgos", "Eleni", "Nikos", "Katerina", "Kostas"], ["Papadopoulos", "Nikolaidis", "Georgiou", "Pappas"]),
    "Japan": (["Haruto", "Yui", "Sota", "Hina", "Ren"], ["Sato", "Suzuki", "Takahashi", "Tanaka", "Watanabe"]),
}
DOMAINS = ["gmail.com", "yahoo.com", "outlook.com", "abv.bg", "mail.bg", "hotmail.com", "icloud.com", "gmx.de"]

users = []
used_names = set()
N_USERS = 90
for uid in range(1, N_USERS + 1):
    country = random.choices(list(COUNTRY_WEIGHTS), weights=COUNTRY_WEIGHTS.values())[0]
    first = random.choice(NAMES[country][0])
    last = random.choice(NAMES[country][1])
    base = (first[0] + last).lower().replace(" ", "")
    style = random.choice(["{b}{n}", "{f}_{l}", "{f}.{l}{n}", "{b}_shop", "{f}{n}"])
    while True:
        uname = style.format(b=base, n=random.randint(1, 999), f=first.lower(), l=last.lower().replace(" ", ""))
        if uname not in used_names:
            used_names.add(uname)
            break
        style = "{b}{n}"
    is_seller = uid <= 38           # първите 38 са продавачи (+ купуват)
    users.append({
        "id": uid, "username": uname,
        "email": f"{uname.replace('_shop', '')}@{random.choice(DOMAINS)}",
        "hash": hashlib.sha256((uname + ":demo").encode()).hexdigest(),
        "first": first, "last": last,
        "phone": f"{PHONE_PREFIX[country]} {random.randint(100, 999)} {random.randint(1000, 9999)}" if random.random() < .8 else None,
        "country": country, "city": random.choice(LOCATIONS[country]),
        "reg": rand_dt(datetime(2012, 1, 1), datetime(2023, 12, 1)),
        "seller": is_seller, "active": random.random() > .03 or is_seller,
    })
# уникални e-mail адреси
seen = set()
for u in users:
    while u["email"] in seen:
        u["email"] = f"{u['username']}{random.randint(1, 99)}@{random.choice(DOMAINS)}"
    seen.add(u["email"])

sellers = [u for u in users if u["seller"]]
active_users = [u for u in users if u["active"]]
user_by_id = {u["id"]: u for u in users}

# ---------------------------------------------------------------------------
# Категории и продукти
# (име, [(шаблон на заглавие, мин цена, макс цена)])
# ---------------------------------------------------------------------------
CATALOG = {
    ("Electronics", "Phones, computers, cameras and gadgets"): {
        "Cell Phones & Smartphones": [("Apple iPhone {v} {s}GB", 180, 1100, ["12", "13", "14 Pro", "15", "15 Pro Max", "16"], ["128", "256", "512"]),
                                      ("Samsung Galaxy {v} {s}GB", 120, 950, ["S21", "S22 Ultra", "S23", "S24", "A54", "Z Flip5"], ["128", "256"]),
                                      ("Google Pixel {v} {s}GB", 150, 800, ["7", "7a", "8", "8 Pro", "9"], ["128", "256"])],
        "Laptops & Netbooks": [("Apple MacBook {v} {s}GB RAM", 450, 2400, ["Air M1", "Air M2", "Pro 14 M3", "Pro 16 M1 Pro"], ["8", "16", "32"]),
                               ("Lenovo ThinkPad {v} {s}GB RAM", 200, 1300, ["T14", "X1 Carbon Gen 9", "E15", "P1"], ["8", "16", "32"]),
                               ("Dell XPS {v} {s}GB RAM", 350, 1700, ["13", "15", "17"], ["16", "32"])],
        "Cameras & Photo": [("Canon EOS {v} Body", 250, 2300, ["R6", "R8", "90D", "5D Mark IV", "M50"], [""]),
                            ("Sony Alpha {v} Mirrorless Camera", 350, 2500, ["A7 III", "A7 IV", "A6400", "A6700"], [""]),
                            ("Fujifilm X-{v} Camera Kit", 400, 1800, ["T4", "T5", "S20", "E4"], [""])],
        "Video Game Consoles": [("Sony PlayStation 5 {v}", 300, 650, ["Disc Edition", "Digital Edition", "Slim", "Pro"], [""]),
                                ("Nintendo Switch {v}", 140, 380, ["OLED", "Lite", "V2 Neon"], [""]),
                                ("Microsoft Xbox Series {v}", 200, 520, ["X 1TB", "S 512GB"], [""])],
    },
    ("Fashion", "Clothing, shoes, watches and accessories"): {
        "Men's Shoes": [("Nike Air {v} Size {s}", 60, 320, ["Max 90", "Force 1", "Jordan 1 Mid", "Max 270"], ["41", "42", "43", "44", "45"]),
                        ("Adidas {v} Size {s}", 50, 240, ["Samba OG", "Ultraboost 22", "Gazelle", "Stan Smith"], ["40", "42", "43", "44"])],
        "Women's Clothing": [("Zara {v} Size {s}", 15, 90, ["Wool Blend Coat", "Satin Midi Dress", "Linen Blazer"], ["XS", "S", "M", "L"]),
                             ("Levi's {v} Jeans W{s}", 25, 110, ["501 Original", "Ribcage Straight", "Wedgie Fit"], ["25", "27", "28", "30"])],
        "Wristwatches": [("Seiko {v} Automatic", 120, 900, ["Presage Cocktail Time", "5 Sports SRPD", "Prospex Turtle"], [""]),
                         ("Casio G-Shock {v}", 60, 400, ["GA-2100", "GW-M5610", "Mudmaster GWG-1000"], [""]),
                         ("Omega {v} (pre-owned)", 2200, 6800, ["Seamaster Diver 300M", "Speedmaster Professional"], [""])],
    },
    ("Home & Garden", "Furniture, kitchen, tools and garden"): {
        "Kitchen Appliances": [("KitchenAid {v} Stand Mixer", 180, 520, ["Artisan 4.8L", "Classic 4.3L", "Heavy Duty 6.9L"], [""]),
                               ("De'Longhi {v} Coffee Machine", 150, 900, ["Magnifica S", "Dedica EC685", "La Specialista"], [""]),
                               ("Ninja {v} Air Fryer", 70, 260, ["AF100", "Foodi Dual Zone", "Max XL"], [""])],
        "Power Tools": [("Makita {v} Cordless Drill Set", 90, 420, ["DHP482", "DDF484", "DHP486"], [""]),
                        ("Bosch Professional {v}", 70, 380, ["GSB 18V-55", "GWS 18V-10 Grinder", "GKS 18V Saw"], [""]),
                        ("DeWalt {v} Combo Kit", 150, 560, ["DCK266", "DCD796", "DCK2050"], [""])],
        "Garden & Patio": [("Husqvarna {v} Lawn Mower", 220, 1400, ["LC 141", "Automower 305", "LC 347V"], [""]),
                           ("Weber {v} BBQ Grill", 180, 1100, ["Spirit II E-310", "Master-Touch 57cm", "Genesis E-325s"], [""])],
    },
    ("Collectibles & Art", "Coins, stamps, trading cards and art"): {
        "Coins & Paper Money": [("{v} Silver Coin {s}", 20, 650, ["1 oz American Eagle", "Morgan Dollar", "Austrian Philharmonic", "Bulgarian 1 Lev 1913"], ["UNC", "MS63", "VF", "Proof"]),
                                ("{v} Gold Coin", 400, 2600, ["1/4 oz Krugerrand", "1/10 oz Britannia", "British Sovereign 1912"], [""])],
        "Trading Cards": [("Pokemon {v} Card PSA {s}", 15, 1800, ["Charizard Base Set", "Pikachu Illustrator Promo Reprint", "Umbreon VMAX Alt Art", "Mewtwo GX"], ["8", "9", "10"]),
                          ("Magic: The Gathering {v}", 10, 900, ["Black Lotus Proxy Lot", "Ragavan Foil", "The One Ring", "Sheoldred"], [""])],
        "Art Prints & Paintings": [("Original Oil Painting \"{v}\" {s}cm", 40, 1200, ["Sunset over Pirin", "Old Town Plovdiv", "Abstract Blue", "Harbor at Dawn"], ["40x50", "60x80", "30x40"])],
    },
    ("Sporting Goods", "Fitness, cycling, outdoor and team sports"): {
        "Fitness Equipment": [("Bowflex {v} Adjustable Dumbbells", 150, 520, ["SelectTech 552", "SelectTech 1090"], [""]),
                              ("Rogue {v}", 80, 900, ["Ohio Bar 20kg", "Monster Lite Rack", "Bumper Plates Set 100kg"], [""]),
                              ("Everlast {v} Boxing Gloves {s}oz", 25, 120, ["Pro Style", "Elite 2", "PowerLock 2"], ["12", "14", "16"])],
        "Cycling": [("Trek {v} Bike Size {s}", 350, 3200, ["Marlin 7", "Domane AL 3", "FX 3 Disc", "Fuel EX 8"], ["M", "L", "XL"]),
                    ("Garmin Edge {v} Bike Computer", 120, 520, ["530", "840", "1040"], [""])],
        "Camping & Hiking": [("The North Face {v}", 60, 450, ["Stormbreak 2 Tent", "Borealis Backpack", "ThermoBall Jacket"], [""]),
                             ("Osprey {v} Backpack", 70, 300, ["Atmos AG 65", "Talon 22", "Exos 48"], [""])],
    },
    ("Toys & Hobbies", "LEGO, models, RC and board games"): {
        "LEGO": [("LEGO {v} Set {s} - Sealed", 25, 850, ["Star Wars Millennium Falcon", "Technic Porsche 911 GT3", "Icons Titanic", "Creator Eiffel Tower", "Harry Potter Hogwarts Castle"], ["75192", "42056", "10294", "10307", "71043"])],
        "RC Models & Kits": [("Traxxas {v} RC Car", 180, 900, ["Slash 4x4", "Maxx V2", "Rustler VXL"], [""]),
                             ("DJI {v} Drone", 250, 1600, ["Mini 3 Pro", "Mini 4 Pro", "Air 3", "Avata 2"], [""])],
        "Board Games": [("{v} Board Game", 20, 160, ["Catan", "Gloomhaven", "Wingspan", "Ticket to Ride Europe", "Terraforming Mars"], [""])],
    },
    ("Books, Movies & Music", "Books, vinyl records and media"): {
        "Books": [("\"{v}\" First Edition", 15, 900, ["Harry Potter and the Philosopher's Stone", "The Hobbit", "Dune", "1984"], [""]),
                  ("{v} Book Lot ({s} books)", 10, 80, ["Programming", "Science Fiction", "Cookbooks", "History"], ["5", "10", "20"])],
        "Vinyl Records": [("{v} - Vinyl LP", 18, 450, ["Pink Floyd The Dark Side of the Moon 1973", "The Beatles Abbey Road", "Daft Punk Random Access Memories", "Fleetwood Mac Rumours"], [""])],
    },
    ("Motors Parts & Accessories", "Car and motorcycle parts"): {
        "Car Parts": [("Bosch {v} for {s}", 25, 350, ["Brake Pads Set", "Alternator", "Wiper Blades Kit", "Fuel Pump"], ["VW Golf 7", "BMW E90", "Audi A4 B8", "Toyota Corolla"]),
                      ("{v} Alloy Wheels 18\" Set of 4", 300, 1500, ["BBS CH-R", "OZ Racing Ultraleggera", "Original BMW M Style"], [""])],
        "Motorcycle Parts": [("Akrapovic {v} Exhaust", 300, 1500, ["Slip-On Yamaha MT-07", "Racing Line KTM Duke 390", "Slip-On Kawasaki Z900"], [""]),
                             ("Shoei {v} Helmet Size {s}", 250, 750, ["NXR2", "GT-Air 3", "X-SPR Pro"], ["S", "M", "L"])],
    },
}

categories = []           # dict(id, parent, name, desc)
subcats = []              # (cat_id, products)
cid = 0
for (pname, pdesc), subs in CATALOG.items():
    cid += 1
    parent_id = cid
    categories.append({"id": parent_id, "parent": None, "name": pname, "desc": pdesc})
    for sname, products in subs.items():
        cid += 1
        categories.append({"id": cid, "parent": parent_id, "name": sname, "desc": f"{sname} in {pname}"})
        subcats.append((cid, products))
# популярност на подкатегориите
subcat_weights = [random.uniform(.5, 2.5) for _ in subcats]

CONDITIONS = ["New", "Used", "Refurbished", "For parts"]
COND_W = [42, 45, 10, 3]
DESCRIPTIONS = [
    "Excellent condition, fully tested and working. Ships within 1 business day.",
    "Original box and all accessories included. Smoke-free home.",
    "Minor signs of use, see photos. No returns on auctions.",
    "Brand new, factory sealed. Fast and well-packed shipping.",
    "Lightly used, works perfectly. Combined shipping available.",
    "Sold as shown in the pictures. Please ask questions before bidding.",
]

# ---------------------------------------------------------------------------
# Обяви, наддавания, продажби
# ---------------------------------------------------------------------------
listings, bids, sales = [], [], []    # sales: dict(listing, buyer, qty, price, ship, date, kind)
N_LISTINGS = 520
bid_id = 0
for lid in range(1, N_LISTINGS + 1):
    seller = random.choice(sellers)
    cat_id, products = random.choices(subcats, weights=subcat_weights)[0]
    tpl, pmin, pmax, vs, ss = random.choice(products)
    title = tpl.format(v=random.choice(vs), s=random.choice(ss)).replace("  ", " ").strip()
    cond = random.choices(CONDITIONS, weights=COND_W)[0]
    base_price = random.uniform(pmin, pmax) * (1.0 if cond == "New" else .78 if cond != "For parts" else .35)
    fmt = "Auction" if random.random() < .45 else "BuyItNow"
    ship = random.choice([0.0, 0.0, 4.99, 7.5, 9.99, 12.0, 15.0, 19.99, 25.0])

    # Активни обяви: последните ~12% са започнали наскоро
    if lid > N_LISTINGS * .88:
        start = rand_dt(datetime(2026, 11, 8), datetime(2026, 11, 22))
    else:
        start = rand_dt(START, datetime(2026, 11, 5))

    views = random.randint(15, 400)
    if fmt == "Auction":
        start_price = money(max(.99, base_price * random.choice([.1, .3, .5, .7])))
        bin_price = money(base_price * 1.15) if random.random() < .2 else None
        if bin_price is not None and bin_price < start_price:
            bin_price = None
        end = start + timedelta(days=random.choice([3, 5, 7, 7, 7, 10]))
        qty = 1
        # наддавания
        n_bids = random.choices([0, 1, 2, 3, 5, 8, 12, 18], weights=[12, 10, 12, 14, 18, 16, 11, 7])[0]
        bid_end = min(end, NOW)
        times = sorted(rand_dt(start + timedelta(minutes=30), bid_end) for _ in range(n_bids))
        price, amount = start_price, None
        bidders = [u for u in active_users if u["id"] != seller["id"]]
        last_bidder = None
        listing_bids = []
        for t in times:
            if amount is None:
                amount = start_price
            else:
                amount = money(amount + bid_increment(amount) * random.choice([1, 1, 2, 3, 5, 10]))
            if bin_price is not None and amount >= bin_price:
                bin_price = None           # BIN опцията изчезва, щом търгът надмине цената
            b = random.choice(bidders)
            while last_bidder is not None and b["id"] == last_bidder:
                b = random.choice(bidders)
            last_bidder = b["id"]
            bid_id += 1
            listing_bids.append({"id": bid_id, "listing": lid, "bidder": b["id"], "amount": amount, "time": t})
        bids.extend(listing_bids)
        if end <= NOW:
            if listing_bids:
                status = "Sold"
                win = listing_bids[-1]
                sales.append({"listing": lid, "buyer": win["bidder"], "qty": 1, "price": win["amount"],
                              "ship": ship, "date": end + timedelta(seconds=1), "kind": "Auction"})
            else:
                status = "Ended"
        else:
            status = "Active"
        views += 25 * len(listing_bids)
        listings.append({"id": lid, "seller": seller["id"], "cat": cat_id, "title": title, "cond": cond,
                         "fmt": fmt, "start_price": start_price, "bin": bin_price, "qty": qty, "ship": ship,
                         "start": start, "end": end, "status": status, "views": views})
    else:
        price = money(base_price)
        qty = random.choices([1, 1, 2, 3, 5, 10, 20], weights=[30, 15, 12, 12, 12, 12, 7])[0]
        end = start + timedelta(days=30)
        window_end = min(end, NOW)
        n_sales = min(qty, random.choices(range(0, qty + 1), k=1)[0] + (1 if random.random() < .55 else 0))
        listing_sales = []
        for _ in range(n_sales):
            b = random.choice([u for u in active_users if u["id"] != seller["id"]])
            listing_sales.append({"listing": lid, "buyer": b["id"], "qty": 1, "price": price, "ship": ship,
                                  "date": rand_dt(start + timedelta(hours=1), window_end), "kind": "BuyItNow"})
        sales.extend(listing_sales)
        listings.append({"id": lid, "seller": seller["id"], "cat": cat_id, "title": title, "cond": cond,
                         "fmt": fmt, "start_price": price, "bin": price, "qty": qty, "ship": ship,
                         "start": start, "end": end, "status": None, "views": views + 20 * n_sales})

listing_by_id = {l["id"]: l for l in listings}

# ---------------------------------------------------------------------------
# Групиране на продажбите в поръчки (част от поръчките са с няколко реда)
# ---------------------------------------------------------------------------
sales.sort(key=lambda s: s["date"])
orders = []      # dict(id, buyer, date, items[list of sale], kind)
for s in sales:
    merged = False
    if s["kind"] == "BuyItNow" and random.random() < .22 and orders:
        # добави към скорошна „Купи сега“ поръчка на друг купувач в рамките на 2 дни
        for o in reversed(orders[-15:]):
            l = listing_by_id[s["listing"]]
            if (o["kind"] == "BuyItNow" and abs((s["date"] - o["date"]).total_seconds()) < 2 * 86400
                    and all(i["listing"] != s["listing"] for i in o["items"])
                    and l["seller"] != o["buyer"]
                    and l["start"] <= o["date"] <= l["end"] and o["date"] <= NOW):
                s["buyer"], s["date"] = o["buyer"], o["date"]
                o["items"].append(s)
                merged = True
                break
    if not merged:
        orders.append({"buyer": s["buyer"], "date": s["date"], "items": [s], "kind": s["kind"]})

# сливане на два реда за един и същ листинг в една поръчка не е позволено – вече проверено
CARRIERS_DOMESTIC = {"Bulgaria": ["Speedy", "Econt"], "United States": ["USPS", "UPS", "FedEx"],
                     "United Kingdom": ["Royal Mail", "DPD"], "Germany": ["DHL", "Hermes"]}
CARRIERS_INTL = ["DHL Express", "UPS", "FedEx", "USPS", "DPD", "Royal Mail"]
METHODS = ["PayPal", "Credit Card", "Debit Card", "Apple Pay", "Google Pay"]
METHOD_W = [40, 27, 15, 10, 8]

payments, shipments, order_items, feedback = [], [], [], []
oi_id = pay_id = ship_id = fb_id = 0
POS_COMMENTS = ["Great seller, fast shipping!", "Item exactly as described. A+++", "Perfect transaction, thank you!",
                "Well packed and arrived quickly.", "Excellent communication. Recommended!", "Super fast delivery, 5 stars.",
                "Great buyer, quick payment!", "Smooth transaction, would buy again."]
NEU_COMMENTS = ["Item OK, shipping was slow.", "Average condition, as expected for the price.", "Took a while to arrive."]
NEG_COMMENTS = ["Item not as described.", "Arrived damaged, seller was unhelpful.", "Never received tracking updates.",
                "Poor packaging, item broken."]
TRACK = {"USPS": "9400", "UPS": "1Z", "FedEx": "7712", "DHL": "JJD", "DHL Express": "JD0", "Speedy": "SP",
         "Econt": "EC", "Royal Mail": "RM", "DPD": "DPD", "Hermes": "H10"}

for idx, o in enumerate(orders, start=1):
    o["id"] = idx
    buyer = user_by_id[o["buyer"]]
    total = 0.0
    for s in o["items"]:
        oi_id += 1
        s["oi_id"] = oi_id
        order_items.append({"id": oi_id, "order": idx, "listing": s["listing"], "qty": s["qty"],
                            "price": s["price"], "ship": s["ship"]})
        total += s["qty"] * s["price"] + s["ship"]
    total = money(total)
    o["total"] = total

    # времева линия
    pay_at = o["date"] + (timedelta(hours=random.uniform(.2, 40)) if o["kind"] == "Auction" else timedelta(seconds=30))
    ship_at = pay_at + timedelta(days=random.uniform(.5, 3))
    seller_country = user_by_id[listing_by_id[o["items"][0]["listing"]]["seller"]]["country"]
    domestic = seller_country == buyer["country"]
    deliver_at = ship_at + timedelta(days=random.uniform(1, 4) if domestic else random.uniform(4, 16))
    roll = random.random()

    if pay_at > NOW:
        status = "Pending"
    elif ship_at > NOW:
        status = "Paid"
    elif deliver_at > NOW:
        status = "Shipped"
    else:
        status = "Delivered"
    if status in ("Paid", "Delivered") and o["kind"] == "BuyItNow" and roll < .04:
        status = "Cancelled"
    elif status == "Delivered" and roll > .94:
        status = "Returned"
    o["status"] = status

    o["address"] = f"{random.randint(1, 240)} {random.choice(['Main St', 'Vitosha Blvd', 'Oak Avenue', 'Park Lane', 'Rakovski St', 'King Street', 'Hauptstrasse', 'Rue de Rivoli'])}"
    o["city"], o["country"] = buyer["city"], buyer["country"]

    if status != "Pending":
        pay_id += 1
        payments.append({"id": pay_id, "order": idx, "method": random.choices(METHODS, weights=METHOD_W)[0],
                         "amount": total, "date": pay_at,
                         "status": "Refunded" if status in ("Cancelled", "Returned") else "Completed",
                         "ref": f"TX-{pay_id:06d}{random.randint(100000, 999999)}"})
    if status in ("Shipped", "Delivered", "Returned"):
        ship_id += 1
        carrier = random.choice(CARRIERS_DOMESTIC.get(buyer["country"], CARRIERS_INTL) if domestic else CARRIERS_INTL)
        shipments.append({"id": ship_id, "order": idx, "carrier": carrier,
                          "tracking": f"{TRACK[carrier]}{random.randint(10**9, 10**10 - 1)}{ship_id:04d}",
                          "shipped": ship_at,
                          "delivered": deliver_at if status in ("Delivered", "Returned") else None,
                          "status": {"Shipped": "In transit", "Delivered": "Delivered", "Returned": "Returned"}[status]})
    # оценки
    if status in ("Delivered", "Returned"):
        for s in o["items"]:
            seller_id = listing_by_id[s["listing"]]["seller"]
            if random.random() < (.78 if status == "Delivered" else .65):
                if status == "Delivered":
                    r = random.choices([1, 0, -1], weights=[93, 4, 3])[0]
                else:
                    r = random.choices([1, 0, -1], weights=[15, 30, 55])[0]
                c = random.choice({1: POS_COMMENTS[:6], 0: NEU_COMMENTS, -1: NEG_COMMENTS}[r]) if random.random() < .85 else None
                fb_id += 1
                feedback.append({"id": fb_id, "oi": s["oi_id"], "from": o["buyer"], "to": seller_id, "rating": r,
                                 "comment": c, "date": min(NOW, deliver_at + timedelta(days=random.uniform(.1, 9)))})
            if random.random() < .6:
                fb_id += 1
                feedback.append({"id": fb_id, "oi": s["oi_id"], "from": seller_id, "to": o["buyer"],
                                 "rating": 1 if random.random() < .97 else 0,
                                 "comment": random.choice(POS_COMMENTS[6:]) if random.random() < .7 else None,
                                 "date": min(NOW, deliver_at + timedelta(days=random.uniform(.5, 12)))})

# статус и продадено количество на „Купи сега“ обявите (отказаните поръчки не се броят)
sold_qty = {}
for o in orders:
    if o["status"] != "Cancelled":
        for s in o["items"]:
            sold_qty[s["listing"]] = sold_qty.get(s["listing"], 0) + s["qty"]
for l in listings:
    l["sold"] = sold_qty.get(l["id"], 0)
    if l["fmt"] == "BuyItNow":
        if l["sold"] >= l["qty"]:
            l["status"] = "Sold"
        elif l["end"] <= NOW:
            l["status"] = "Ended"
        else:
            l["status"] = "Active"
    else:
        l["sold"] = 1 if l["status"] == "Sold" else 0

# feedback: сортиране по дата (ID-тата отразяват хронологията)
feedback.sort(key=lambda f: f["date"])
for i, f in enumerate(feedback, start=1):
    f["id"] = i

# ---------------------------------------------------------------------------
# Watchlist
# ---------------------------------------------------------------------------
watch = {}
for _ in range(900):
    l = random.choice(listings)
    u = random.choice(active_users)
    if u["id"] == l["seller"] or (u["id"], l["id"]) in watch:
        continue
    watch[(u["id"], l["id"])] = rand_dt(l["start"], min(l["end"], NOW))

# ---------------------------------------------------------------------------
# Запис на SQL
# ---------------------------------------------------------------------------
def insert_block(f, table, cols, rows, identity=True, chunk=400):
    f.write(f"\n/* ---- {table}: {len(rows)} реда ---- */\n")
    if identity:
        f.write(f"SET IDENTITY_INSERT dbo.{table} ON;\n")
    for i in range(0, len(rows), chunk):
        part = rows[i:i + chunk]
        f.write(f"INSERT INTO dbo.{table} ({', '.join(cols)}) VALUES\n")
        f.write(",\n".join("(" + ", ".join(q(v) for v in r) + ")" for r in part))
        f.write(";\n")
    if identity:
        f.write(f"SET IDENTITY_INSERT dbo.{table} OFF;\n")
    f.write("GO\n")


with open(OUT, "w", encoding="utf-8") as f:
    f.write("/* =====================================================================\n")
    f.write("   Курсова работа – eBay | ф.н. 2401321025\n")
    f.write("   Файл 03: Тестови данни (генерирани от tools/generate_seed.py)\n")
    f.write(f"   Период на данните: {START:%Y-%m-%d} – {NOW:%Y-%m-%d}\n")
    f.write("   CurrentPrice, FeedbackScore и TotalAmount се изчисляват от тригерите.\n")
    f.write("   ===================================================================== */\n\n")
    f.write("USE eBayDB;\nGO\nSET NOCOUNT ON;\nGO\n")

    insert_block(f, "Users", ["UserID", "Username", "Email", "PasswordHash", "FirstName", "LastName", "Phone",
                              "Country", "City", "RegistrationDate", "IsSeller", "FeedbackScore", "IsActive"],
                 [(u["id"], u["username"], u["email"], u["hash"], u["first"], u["last"], u["phone"], u["country"],
                   u["city"], u["reg"], u["seller"], 0, u["active"]) for u in users])

    insert_block(f, "Categories", ["CategoryID", "ParentCategoryID", "Name", "Description", "IsActive"],
                 [(c["id"], c["parent"], c["name"], c["desc"], True) for c in categories])

    insert_block(f, "Listings", ["ListingID", "SellerID", "CategoryID", "Title", "Description", "ItemCondition",
                                 "ListingFormat", "StartPrice", "BuyItNowPrice", "CurrentPrice", "Quantity",
                                 "QuantitySold", "ShippingCost", "StartDate", "EndDate", "Status", "ViewCount"],
                 [(l["id"], l["seller"], l["cat"], l["title"], random.choice(DESCRIPTIONS), l["cond"], l["fmt"],
                   float(l["start_price"]), None if l["bin"] is None else float(l["bin"]), float(l["start_price"]),
                   l["qty"], l["sold"], float(l["ship"]), l["start"], l["end"], l["status"], l["views"])
                  for l in listings])

    insert_block(f, "Bids", ["BidID", "ListingID", "BidderID", "BidAmount", "BidTime"],
                 [(b["id"], b["listing"], b["bidder"], float(b["amount"]), b["time"]) for b in bids])

    insert_block(f, "Watchlist", ["UserID", "ListingID", "AddedDate"],
                 [(k[0], k[1], v) for k, v in sorted(watch.items())], identity=False)

    insert_block(f, "Orders", ["OrderID", "BuyerID", "OrderDate", "Status", "ShippingAddress", "ShippingCity",
                               "ShippingCountry", "TotalAmount"],
                 [(o["id"], o["buyer"], o["date"], o["status"], o["address"], o["city"], o["country"], 0.0)
                  for o in orders])

    insert_block(f, "OrderItems", ["OrderItemID", "OrderID", "ListingID", "Quantity", "UnitPrice", "ShippingCost"],
                 [(i["id"], i["order"], i["listing"], i["qty"], float(i["price"]), float(i["ship"])) for i in order_items])

    insert_block(f, "Payments", ["PaymentID", "OrderID", "PaymentMethod", "Amount", "PaymentDate", "Status", "TransactionRef"],
                 [(p["id"], p["order"], p["method"], float(p["amount"]), p["date"], p["status"], p["ref"]) for p in payments])

    insert_block(f, "Shipments", ["ShipmentID", "OrderID", "Carrier", "TrackingNumber", "ShippedDate", "DeliveredDate", "ShippingStatus"],
                 [(s["id"], s["order"], s["carrier"], s["tracking"], s["shipped"], s["delivered"], s["status"]) for s in shipments])

    insert_block(f, "Feedback", ["FeedbackID", "OrderItemID", "FromUserID", "ToUserID", "Rating", "Comment", "CreatedAt"],
                 [(x["id"], x["oi"], x["from"], x["to"], x["rating"], x["comment"], x["date"]) for x in feedback])

    f.write("\nPRINT N'Тестовите данни са заредени.';\n")
    f.write("SELECT 'Users' AS TableName, COUNT(*) AS Rows FROM dbo.Users UNION ALL\n"
            "SELECT 'Categories', COUNT(*) FROM dbo.Categories UNION ALL\n"
            "SELECT 'Listings', COUNT(*) FROM dbo.Listings UNION ALL\n"
            "SELECT 'Bids', COUNT(*) FROM dbo.Bids UNION ALL\n"
            "SELECT 'Watchlist', COUNT(*) FROM dbo.Watchlist UNION ALL\n"
            "SELECT 'Orders', COUNT(*) FROM dbo.Orders UNION ALL\n"
            "SELECT 'OrderItems', COUNT(*) FROM dbo.OrderItems UNION ALL\n"
            "SELECT 'Payments', COUNT(*) FROM dbo.Payments UNION ALL\n"
            "SELECT 'Shipments', COUNT(*) FROM dbo.Shipments UNION ALL\n"
            "SELECT 'Feedback', COUNT(*) FROM dbo.Feedback;\nGO\n")

print(f"Users={len(users)} Categories={len(categories)} Listings={len(listings)} Bids={len(bids)} "
      f"Watchlist={len(watch)} Orders={len(orders)} OrderItems={len(order_items)} Payments={len(payments)} "
      f"Shipments={len(shipments)} Feedback={len(feedback)}")
print("->", os.path.normpath(OUT))
