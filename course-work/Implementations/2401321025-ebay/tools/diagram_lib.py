"""
Малка библиотека, която от едно описание на диаграма генерира
едновременно draw.io (.drawio) файл и SVG (за преглед / PNG).
"""
import html
import math

FONT = "Segoe UI, Helvetica, Arial, sans-serif"


def esc(t):
    return html.escape(str(t), quote=True)


class Diagram:
    def __init__(self, name, width, height):
        self.name, self.W, self.H = name, width, height
        self.cells = []      # draw.io XML фрагменти
        self.svg = []        # SVG фрагменти (рисуват се по ред)
        self.svg_top = []    # етикети отгоре
        self.n = 1
        self.geom = {}       # id -> (x, y, w, h)

    def nid(self, prefix="c"):
        self.n += 1
        return f"{prefix}{self.n}"

    # ------------------------------------------------------------------
    # Основни фигури
    # ------------------------------------------------------------------
    def text(self, x, y, w, h, value, size=12, bold=False, color="#333333", align="center", italic=False):
        cid = self.nid("t")
        fs = (1 if bold else 0) + (2 if italic else 0)
        self.cells.append(
            f'<mxCell id="{cid}" value="{esc(value)}" style="text;html=0;align={align};verticalAlign=middle;'
            f'fontSize={size};fontStyle={fs};fontColor={color};strokeColor=none;fillColor=none;" vertex="1" parent="1">'
            f'<mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry"/></mxCell>')
        anchor = {"center": "middle", "left": "start", "right": "end"}[align]
        tx = x + w / 2 if align == "center" else (x + 4 if align == "left" else x + w - 4)
        self.svg_top.append(
            f'<text x="{tx}" y="{y + h / 2 + size * .35}" font-size="{size}" text-anchor="{anchor}" '
            f'font-weight="{"bold" if bold else "normal"}" font-style="{"italic" if italic else "normal"}" '
            f'fill="{color}" font-family="{FONT}">{esc(value)}</text>')
        return cid

    def rect(self, x, y, w, h, value, fill="#dae8fc", stroke="#6c8ebf", size=14, bold=True, double=False):
        cid = self.nid("e")
        self.geom[cid] = (x, y, w, h)
        style = (f"rounded=0;whiteSpace=wrap;html=0;fillColor={fill};strokeColor={stroke};fontSize={size};"
                 f"fontStyle={1 if bold else 0};strokeWidth=1.5;")
        if double:
            style = (f"shape=associativeEntity;whiteSpace=wrap;html=0;fillColor={fill};strokeColor={stroke};"
                     f"fontSize={size};fontStyle={1 if bold else 0};strokeWidth=1.5;")
        self.cells.append(f'<mxCell id="{cid}" value="{esc(value)}" style="{style}" vertex="1" parent="1">'
                          f'<mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry"/></mxCell>')
        self.svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="{stroke}" stroke-width="1.5"/>')
        if double:   # асоциативна същност – ромб вътре в правоъгълника
            cx, cy = x + w / 2, y + h / 2
            self.svg.append(f'<polygon points="{x},{cy} {cx},{y} {x + w},{cy} {cx},{y + h}" fill="none" '
                            f'stroke="{stroke}" stroke-width="1.2"/>')
        self.svg_top.append(f'<text x="{x + w / 2}" y="{y + h / 2 + size * .35}" font-size="{size}" '
                            f'text-anchor="middle" font-weight="{"bold" if bold else "normal"}" '
                            f'font-family="{FONT}" fill="#111">{esc(value)}</text>')
        return cid

    def ellipse(self, cx, cy, value, key=False, fill="#fff2cc", stroke="#d6b656", size=12, w=None):
        w = w or max(70, int(len(value) * size * .58) + 26)
        h = 34
        x, y = cx - w / 2, cy - h / 2
        cid = self.nid("a")
        self.geom[cid] = (x, y, w, h)
        fs = 4 if key else 0     # 4 = подчертано
        self.cells.append(f'<mxCell id="{cid}" value="{esc(value)}" style="ellipse;whiteSpace=wrap;html=0;'
                          f'fillColor={fill};strokeColor={stroke};fontSize={size};fontStyle={fs};" vertex="1" parent="1">'
                          f'<mxGeometry x="{x:.0f}" y="{y:.0f}" width="{w}" height="{h}" as="geometry"/></mxCell>')
        self.svg.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{w / 2}" ry="{h / 2}" fill="{fill}" stroke="{stroke}" stroke-width="1.2"/>')
        deco = ' text-decoration="underline"' if key else ""
        self.svg_top.append(f'<text x="{cx}" y="{cy + size * .35}" font-size="{size}" text-anchor="middle"{deco} '
                            f'font-family="{FONT}" fill="#222">{esc(value)}</text>')
        return cid

    def diamond(self, cx, cy, value, w=150, h=70, fill="#f8cecc", stroke="#b85450", size=12):
        x, y = cx - w / 2, cy - h / 2
        cid = self.nid("r")
        self.geom[cid] = (x, y, w, h)
        self.cells.append(f'<mxCell id="{cid}" value="{esc(value)}" style="rhombus;whiteSpace=wrap;html=0;'
                          f'fillColor={fill};strokeColor={stroke};fontSize={size};fontStyle=1;strokeWidth=1.5;" vertex="1" parent="1">'
                          f'<mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry"/></mxCell>')
        self.svg.append(f'<polygon points="{x},{cy} {cx},{y} {x + w},{cy} {cx},{y + h}" fill="{fill}" stroke="{stroke}" stroke-width="1.5"/>')
        self.svg_top.append(f'<text x="{cx}" y="{cy + size * .35}" font-size="{size}" text-anchor="middle" '
                            f'font-weight="bold" font-family="{FONT}" fill="#111">{esc(value)}</text>')
        return cid

    # ------------------------------------------------------------------
    # Линии
    # ------------------------------------------------------------------
    def line(self, src, dst, label=None, label_pos=0.5, width=1.2, color="#555555"):
        """Права линия между центровете на две фигури (подрязана до контура в SVG)."""
        cid = self.nid("l")
        lab = f' value="{esc(label)}"' if label else ' value=""'
        self.cells.append(f'<mxCell id="{cid}"{lab} style="endArrow=none;html=0;strokeColor={color};strokeWidth={width};'
                          f'fontSize=13;fontStyle=1;labelBackgroundColor=#ffffff;" edge="1" parent="1" source="{src}" target="{dst}">'
                          f'<mxGeometry x="{(label_pos - .5) * 2:.2f}" relative="1" as="geometry"/></mxCell>')
        (x1, y1), (x2, y2) = self._center(src), self._center(dst)
        self.svg.insert(0, f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{width}"/>')
        if label:
            # позицията на етикета – по видимата част на линията
            p1, p2 = self._clip(src, (x2, y2)), self._clip(dst, (x1, y1))
            lx, ly = p1[0] + (p2[0] - p1[0]) * label_pos, p1[1] + (p2[1] - p1[1]) * label_pos
            self.svg_top.append(f'<rect x="{lx - 9}" y="{ly - 10}" width="18" height="19" fill="#fff"/>'
                                f'<text x="{lx}" y="{ly + 5}" font-size="13" font-weight="bold" text-anchor="middle" '
                                f'font-family="{FONT}" fill="#c0392b">{esc(label)}</text>')
        return cid

    def _center(self, cid):
        x, y, w, h = self.geom[cid]
        return x + w / 2, y + h / 2

    def _clip(self, cid, toward):
        """Пресечна точка на отсечката център->toward с правоъгълника на фигурата (приблизително)."""
        x, y, w, h = self.geom[cid]
        cx, cy = x + w / 2, y + h / 2
        dx, dy = toward[0] - cx, toward[1] - cy
        if dx == 0 and dy == 0:
            return cx, cy
        t = min(abs((w / 2) / dx) if dx else 1e9, abs((h / 2) / dy) if dy else 1e9)
        return cx + dx * t, cy + dy * t

    def poly_edge(self, points, src=None, dst=None, start=None, end=None, labels=(), color="#555555",
                  width=1.3, dashed=False):
        """Ортогонална линия по зададени точки. start/end: 'one', 'mone', 'many', 'zmany', 'omany', None."""
        cid = self.nid("p")
        arrow = {None: "none", "one": "ERone", "mone": "ERmandOne", "many": "ERmany",
                 "zmany": "ERzeroToMany", "omany": "ERoneToMany", "zone": "ERzeroToOne"}
        (sx, sy), (tx, ty) = points[0], points[-1]
        attrs = ""
        style = (f"edgeStyle=none;html=0;rounded=0;strokeColor={color};strokeWidth={width};"
                 f"startArrow={arrow[start]};endArrow={arrow[end]};startFill=0;endFill=0;startSize=12;endSize=12;"
                 + ("dashed=1;" if dashed else ""))
        if src:
            x, y, w, h = self.geom[src]
            style += f"exitX={(sx - x) / w:.4f};exitY={(sy - y) / h:.4f};exitDx=0;exitDy=0;"
            attrs += f' source="{src}"'
        if dst:
            x, y, w, h = self.geom[dst]
            style += f"entryX={(tx - x) / w:.4f};entryY={(ty - y) / h:.4f};entryDx=0;entryDy=0;"
            attrs += f' target="{dst}"'
        mid = "".join(f'<mxPoint x="{px}" y="{py}"/>' for px, py in points[1:-1])
        self.cells.append(
            f'<mxCell id="{cid}" value="" style="{style}" edge="1" parent="1"{attrs}>'
            f'<mxGeometry relative="1" as="geometry"><mxPoint x="{sx}" y="{sy}" as="sourcePoint"/>'
            f'<mxPoint x="{tx}" y="{ty}" as="targetPoint"/>'
            + (f'<Array as="points">{mid}</Array>' if mid else "") + '</mxGeometry></mxCell>')
        for (txt, pos, dx, dy) in labels:      # pos: -1 начало, 1 край (draw.io относителни координати)
            lid = self.nid("lb")
            self.cells.append(f'<mxCell id="{lid}" value="{esc(txt)}" style="edgeLabel;html=0;align=center;'
                              f'verticalAlign=middle;resizable=0;points=[];fontSize=12;fontStyle=1;fontColor=#333333;'
                              f'labelBackgroundColor=none;" vertex="1" connectable="0" parent="{cid}">'
                              f'<mxGeometry x="{pos}" relative="1" as="geometry"><mxPoint x="{dx}" y="{dy}" as="offset"/>'
                              f'</mxGeometry></mxCell>')
            px, py = (points[0] if pos < 0 else points[-1])
            self.svg_top.append(f'<text x="{px + dx}" y="{py + dy + 4}" font-size="12" font-weight="bold" '
                                f'text-anchor="middle" font-family="{FONT}" fill="#333">{esc(txt)}</text>')
        pts = " ".join(f"{px},{py}" for px, py in points)
        da = ' stroke-dasharray="6,4"' if dashed else ""
        self.svg.insert(0, f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="{width}"{da}/>')
        if start:
            self.svg_top.append(self._crow(points[0], points[1], start, color))
        if end:
            self.svg_top.append(self._crow(points[-1], points[-2], end, color))
        return cid

    def _crow(self, p, q, kind, color):
        """Маркер Crow's Foot в точка p, линията идва от q."""
        dx, dy = q[0] - p[0], q[1] - p[1]
        L = math.hypot(dx, dy) or 1
        ux, uy = dx / L, dy / L          # посока навътре по линията
        nx, ny = -uy, ux                 # нормала
        out = []

        def bar(d):
            cx, cy = p[0] + ux * d, p[1] + uy * d
            out.append(f'<line x1="{cx + nx * 7}" y1="{cy + ny * 7}" x2="{cx - nx * 7}" y2="{cy - ny * 7}" stroke="{color}" stroke-width="1.5"/>')

        def circle(d):
            cx, cy = p[0] + ux * d, p[1] + uy * d
            out.append(f'<circle cx="{cx}" cy="{cy}" r="5" fill="#fff" stroke="{color}" stroke-width="1.5"/>')

        def foot():
            tip = (p[0] + ux * 13, p[1] + uy * 13)
            for s in (-1, 0, 1):
                ex, ey = p[0] + nx * 8 * s, p[1] + ny * 8 * s
                out.append(f'<line x1="{tip[0]}" y1="{tip[1]}" x2="{ex}" y2="{ey}" stroke="{color}" stroke-width="1.5"/>')

        if kind == "mone":
            bar(8); bar(14)
        elif kind == "one":
            bar(10)
        elif kind == "zone":
            bar(8); circle(18)
        elif kind == "many":
            foot()
        elif kind == "zmany":
            foot(); circle(19)
        elif kind == "omany":
            foot(); bar(17)
        return "".join(out)

    # ------------------------------------------------------------------
    # Таблица (за Crow's Foot и UML)
    # ------------------------------------------------------------------
    def table(self, x, y, w, title, rows, header="#dae8fc", stroke="#6c8ebf", stereotype=None, row_h=22,
              key_w=34, type_w=None):
        """rows: [(key, name, type)]. Връща id и запазва геометрията; редовете са отделни клетки."""
        head_h = 46 if stereotype else 30
        h = head_h + row_h * len(rows) + 4
        cid = self.nid("tb")
        self.geom[cid] = (x, y, w, h)
        label = f"«{stereotype}»\n{title}" if stereotype else title
        self.cells.append(
            f'<mxCell id="{cid}" value="{esc(label)}" style="swimlane;fontStyle=1;horizontal=1;'
            f'startSize={head_h};collapsible=0;'
            f'marginBottom=0;html=0;whiteSpace=wrap;fillColor={header};strokeColor={stroke};fontSize=13;swimlaneFillColor=#ffffff;" '
            f'vertex="1" parent="1"><mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" as="geometry"/></mxCell>')
        self.svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#fff" stroke="{stroke}" stroke-width="1.5"/>'
                        f'<rect x="{x}" y="{y}" width="{w}" height="{head_h}" fill="{header}" stroke="{stroke}" stroke-width="1.5"/>')
        if stereotype:
            self.svg_top.append(f'<text x="{x + w / 2}" y="{y + 18}" font-size="11" text-anchor="middle" font-style="italic" '
                                f'font-family="{FONT}" fill="#333">«{esc(stereotype)}»</text>'
                                f'<text x="{x + w / 2}" y="{y + 37}" font-size="14" text-anchor="middle" font-weight="bold" '
                                f'font-family="{FONT}" fill="#111">{esc(title)}</text>')
        else:
            self.svg_top.append(f'<text x="{x + w / 2}" y="{y + 20}" font-size="14" text-anchor="middle" font-weight="bold" '
                                f'font-family="{FONT}" fill="#111">{esc(title)}</text>')
        type_w = type_w or 0
        for i, (key, name, typ) in enumerate(rows):
            ry = head_h + i * row_h
            rid = self.nid("row")
            is_pk = "PK" in key
            fs = (1 if is_pk else 0) + (4 if is_pk else 0)
            text = f"{name}" + (f" : {typ}" if typ else "")
            self.cells.append(
                f'<mxCell id="{rid}k" value="{esc(key)}" style="text;html=0;strokeColor=none;fillColor=none;align=left;'
                f'verticalAlign=middle;spacingLeft=6;fontSize=11;fontStyle=1;fontColor=#7a4b00;" vertex="1" parent="{cid}">'
                f'<mxGeometry y="{ry}" width="{key_w}" height="{row_h}" as="geometry"/></mxCell>')
            self.cells.append(
                f'<mxCell id="{rid}" value="{esc(text)}" style="text;html=0;strokeColor=none;fillColor=none;align=left;'
                f'verticalAlign=middle;spacingLeft=4;fontSize=12;fontStyle={fs};" vertex="1" parent="{cid}">'
                f'<mxGeometry x="{key_w}" y="{ry}" width="{w - key_w}" height="{row_h}" as="geometry"/></mxCell>')
            ty = y + ry + row_h / 2 + 4
            self.svg_top.append(f'<text x="{x + 6}" y="{ty}" font-size="10.5" font-weight="bold" fill="#7a4b00" '
                                f'font-family="{FONT}">{esc(key)}</text>')
            deco = ' text-decoration="underline"' if is_pk else ""
            self.svg_top.append(f'<text x="{x + key_w + 4}" y="{ty}" font-size="12" font-weight="{"bold" if is_pk else "normal"}"{deco} '
                                f'font-family="{FONT}" fill="#111">{esc(name)}<tspan fill="#666">{esc(" : " + typ) if typ else ""}</tspan></text>')
        # разделител под PK редовете
        return cid

    # ------------------------------------------------------------------
    def save(self, drawio_path, svg_path, title=None):
        xml = ('<?xml version="1.0" encoding="UTF-8"?>\n'
               f'<mxfile host="app.diagrams.net" type="device"><diagram id="{self.name}" name="{esc(self.name)}">'
               f'<mxGraphModel dx="{self.W}" dy="{self.H}" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" '
               f'arrows="1" fold="1" page="1" pageScale="1" pageWidth="{self.W}" pageHeight="{self.H}" math="0" shadow="0">'
               '<root><mxCell id="0"/><mxCell id="1" parent="0"/>'
               + "".join(self.cells) + '</root></mxGraphModel></diagram></mxfile>\n')
        with open(drawio_path, "w", encoding="utf-8") as f:
            f.write(xml)
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.W}" height="{self.H}" viewBox="0 0 {self.W} {self.H}">'
               f'<rect width="100%" height="100%" fill="#ffffff"/>' + "".join(self.svg) + "".join(self.svg_top) + "</svg>")
        with open(svg_path, "w", encoding="utf-8") as f:
            f.write(svg)
