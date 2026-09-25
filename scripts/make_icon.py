#!/usr/bin/env python3
"""生成 xEdu 的 launcher 图标：蓝底渐变 + 白色图形，和儿童桌面那套是一家的。

    python3 scripts/make_icon.py preview           # 渲三套候选到 scripts/out/，先看再挑
    python3 scripts/make_icon.py android a         # 把选定方案写进 android/.../res/

**同一份几何数据出两种产物**：PNG（mipmap-*/ic_launcher.png，API 24/25 和第三方桌面
拿到的就是它）和自适应矢量图（drawable/ic_launcher_foreground.xml + mipmap-anydpi-v26/）。
分两处各画一遍迟早会画歪——改一处忘一处，桌面上和系统应用列表里就是两个图标。

只依赖标准库（zlib + struct），不装 Pillow。
"""
import math
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "scripts", "out")

BLUE_TOP = (92, 156, 255)
BLUE_BOT = (34, 88, 214)
DEEP = (36, 92, 205)
WHITE = (255, 255, 255)

VIEW = 108.0          # 自适应图标的 viewport（前景安全区 = 中间 66）
# 图形落进安全区。0.75 是量出来的：图形本身占整格的 0.14~0.86，缩到 75% 后
# 外沿落在 0.23~0.77，比安全区（0.194~0.806）还收一点；帽子的两个尖角离圆形
# 遮罩边界也还留着余量。再大就容易被遮罩啃到角。
SAFE_SCALE = 0.75
SAFE_SHIFT = (VIEW - VIEW * SAFE_SCALE) / 2


# ---------- 几何：形状用数据描述，栅格化和矢量化各有一份后端 ----------

def rrect(x0, y0, x1, y1, r):
    return {"kind": "rrect", "rect": (x0, y0, x1, y1), "r": r}


def circle(cx, cy, r):
    return {"kind": "circle", "c": (cx, cy), "r": r}


def poly(pts):
    return {"kind": "poly", "pts": list(pts)}


def band(cx, cy, r, w, a0, a1):
    """一段圆弧带（笑脸那道嘴）"""
    return {"kind": "band", "c": (cx, cy), "r": r, "w": w, "a0": a0, "a1": a1}


def quad(a, b, c, n=16):
    out = []
    for i in range(n + 1):
        t = i / n
        out.append((
            (1 - t) ** 2 * a[0] + 2 * (1 - t) * t * b[0] + t * t * c[0],
            (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * b[1] + t * t * c[1],
        ))
    return out


def rot(pts, deg, cx, cy):
    a = math.radians(deg)
    ca, sa = math.cos(a), math.sin(a)
    return [((x - cx) * ca - (y - cy) * sa + cx,
             (x - cx) * sa + (y - cy) * ca + cy) for x, y in pts]


def place(pts, cx, cy, deg, size=1.0):
    """把局部坐标（长度 1、以 0 为尖端）摆到图标上：缩到 [size]，转到 [deg] 度"""
    a = math.radians(deg)
    ca, sa = math.cos(a), math.sin(a)
    return [(cx + (x * size) * ca - (y * size) * sa,
             cy + (x * size) * sa + (y * size) * ca) for x, y in pts]


# ---------- 三套候选（归一化 0..1，y 向下） ----------

def design_a():
    """蓝底 + 一本翻开的书：两页上沿朝书脊斜下去，中间一道深蓝书缝"""
    top, dip, bottom = 0.28, 0.46, 0.76
    pts = [(0.14, top)]
    # 外上角磨圆：不磨的话两个尖角看着像帐篷
    pts += quad((0.14, top), (0.20, top), (0.29, top + 0.09))
    pts += [(0.50, dip)]
    pts += [(0.71, top + 0.09)]
    pts += quad((0.71, top + 0.09), (0.80, top), (0.86, top))
    pts += [(0.86, bottom - 0.06)]
    pts += quad((0.86, bottom - 0.06), (0.86, bottom), (0.80, bottom))
    pts += [(0.20, bottom)]
    pts += quad((0.20, bottom), (0.14, bottom), (0.14, bottom - 0.06))
    return [
        (poly(pts), WHITE),
        (rrect(0.483, dip - 0.01, 0.517, bottom, 0.016), DEEP),
    ]


def design_b():
    """蓝底 + 一张戴学士帽的笑脸"""
    return [
        # 帽（方板）
        (poly([(0.50, 0.15), (0.87, 0.31), (0.50, 0.47), (0.13, 0.31)]), WHITE),
        # 帽穗
        (poly([(0.845, 0.33), (0.865, 0.33), (0.875, 0.52), (0.855, 0.52)]), WHITE),
        (circle(0.865, 0.55, 0.033), WHITE),
        # 脸
        (circle(0.50, 0.685, 0.175), WHITE),
        (circle(0.44, 0.645, 0.028), DEEP),
        (circle(0.56, 0.645, 0.028), DEEP),
        (band(0.50, 0.655, 0.075, 0.028,
              math.radians(30), math.radians(150)), DEEP),
    ]


def design_c():
    """蓝底 + 一支斜放的铅笔"""
    w = 0.05
    tipx, tipy, size = 0.20, 0.80, 0.88
    body = place([(0.0, 0.0), (0.14, w), (1.0, w), (1.0, -w), (0.14, -w)],
                 tipx, tipy, -45, size)
    lead = place([(0.0, 0.0), (0.055, 0.024), (0.055, -0.024)],
                 tipx, tipy, -45, size)
    ferrule = place([(0.86, w), (0.915, w), (0.915, -w), (0.86, -w)],
                    tipx, tipy, -45, size)
    return [
        (poly(body), WHITE),
        (poly(ferrule), DEEP),
        (poly(lead), DEEP),
    ]


DESIGNS = {"a": design_a, "b": design_b, "c": design_c}


# ---------- 后端一：栅格化 ----------

def pred(shape):
    """形状 -> (x, y) 是否在里面的判定函数"""
    k = shape["kind"]
    if k == "rrect":
        x0, y0, x1, y1 = shape["rect"]
        r = shape["r"]

        def f(x, y):
            if x < x0 or x > x1 or y < y0 or y > y1:
                return False
            cx = min(max(x, x0 + r), x1 - r)
            cy = min(max(y, y0 + r), y1 - r)
            return (x - cx) ** 2 + (y - cy) ** 2 <= r * r

        return f
    if k == "circle":
        cx, cy = shape["c"]
        r = shape["r"]
        return lambda x, y: (x - cx) ** 2 + (y - cy) ** 2 <= r * r
    if k == "poly":
        pts = shape["pts"]

        def f(x, y):
            inside = False
            n = len(pts)
            for i in range(n):
                ax, ay = pts[i]
                bx, by = pts[(i + 1) % n]
                if (ay > y) != (by > y):
                    if x < (bx - ax) * (y - ay) / (by - ay) + ax:
                        inside = not inside
            return inside

        return f
    if k == "band":
        cx, cy = shape["c"]
        r, w = shape["r"], shape["w"]
        a0, a1 = shape["a0"], shape["a1"]

        def f(x, y):
            dx, dy = x - cx, y - cy
            if abs(math.hypot(dx, dy) - r) > w / 2:
                return False
            a = math.atan2(dy, dx)
            while a < a0:
                a += 2 * math.pi
            return a <= a1

        return f
    raise ValueError(k)


def render(n, layers, ss=3, mask=None):
    inv = 1.0 / (n * ss)
    out = bytearray(n * n * 4)
    for py in range(n):
        for px in range(n):
            r = g = b = 0.0
            hits = 0
            for sy in range(ss):
                for sx in range(ss):
                    x = (px * ss + sx + 0.5) * inv
                    y = (py * ss + sy + 0.5) * inv
                    if mask is not None and not mask(x, y):
                        continue
                    hits += 1
                    t = y
                    col = (BLUE_TOP[0] + (BLUE_BOT[0] - BLUE_TOP[0]) * t,
                           BLUE_TOP[1] + (BLUE_BOT[1] - BLUE_TOP[1]) * t,
                           BLUE_TOP[2] + (BLUE_BOT[2] - BLUE_TOP[2]) * t)
                    for shape, c in layers:
                        if shape(x, y):
                            col = c
                    r += col[0]
                    g += col[1]
                    b += col[2]
            k = ss * ss
            i = (py * n + px) * 4
            if hits:
                out[i] = int(r / hits + 0.5)
                out[i + 1] = int(g / hits + 0.5)
                out[i + 2] = int(b / hits + 0.5)
                out[i + 3] = int(255 * hits / k + 0.5)
    return out


def write_png(path, n, rgba):
    raw = b"".join(b"\x00" + bytes(rgba[y * n * 4:(y + 1) * n * 4]) for y in range(n))

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", n, n, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


def raster(layers):
    return [(pred(s), c) for s, c in layers]


# ---------- 后端二：矢量（Android VectorDrawable 的 pathData） ----------

def hexof(c):
    return "#FF%02X%02X%02X" % c


def pathof(shape, s=1.0):
    """形状 -> (pathData, 是否描边)。坐标按 s 缩放（前景要缩进安全区，PNG 不缩）"""
    k = shape["kind"]
    if k == "poly":
        pts = [(x * s, y * s) for x, y in shape["pts"]]
        d = "M" + " L".join("%.2f,%.2f" % p for p in pts) + " Z"
        return d, False
    if k == "circle":
        cx, cy = shape["c"][0] * s, shape["c"][1] * s
        r = shape["r"] * s
        d = ("M%.2f,%.2f a%.2f,%.2f 0 1 0 %.2f,0 a%.2f,%.2f 0 1 0 %.2f,0 Z"
             % (cx - r, cy, r, r, 2 * r, r, r, -2 * r))
        return d, False
    if k == "rrect":
        x0, y0, x1, y1 = [v * s for v in shape["rect"]]
        r = shape["r"] * s
        # 四段直线 + 四个圆角
        d = ("M%.2f,%.2f L%.2f,%.2f a%.2f,%.2f 0 0 1 %.2f,%.2f "
             "L%.2f,%.2f a%.2f,%.2f 0 0 1 %.2f,%.2f "
             "L%.2f,%.2f a%.2f,%.2f 0 0 1 %.2f,%.2f "
             "L%.2f,%.2f a%.2f,%.2f 0 0 1 %.2f,%.2f Z"
             % (x0 + r, y0, x1 - r, y0, r, r, r, r,
                x1, y1 - r, r, r, -r, r,
                x0 + r, y1, r, r, -r, -r,
                x0, y0 + r, r, r, r, -r))
        return d, False
    if k == "band":
        cx, cy = shape["c"][0] * s, shape["c"][1] * s
        r = shape["r"] * s
        a0, a1 = shape["a0"], shape["a1"]
        x0 = cx + r * math.cos(a0)
        y0 = cy + r * math.sin(a0)
        x1 = cx + r * math.cos(a1)
        y1 = cy + r * math.sin(a1)
        large = 1 if (a1 - a0) > math.pi else 0
        d = "M%.2f,%.2f A%.2f,%.2f 0 %d 1 %.2f,%.2f" % (x0, y0, r, r, large, x1, y1)
        return d, True
    raise ValueError(k)


def foreground_xml(layers):
    body = []
    for shape, c in layers:
        d, stroked = pathof(shape, s=VIEW)
        if stroked:
            w = shape["w"] * VIEW
            body.append(
                '    <path\n'
                '        android:strokeColor="%s"\n'
                '        android:strokeWidth="%.2f"\n'
                '        android:strokeLineCap="round"\n'
                '        android:pathData="%s" />' % (hexof(c), w, d))
        else:
            body.append(
                '    <path\n'
                '        android:fillColor="%s"\n'
                '        android:pathData="%s" />' % (hexof(c), d))
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!-- 由 scripts/make_icon.py 生成，别手改：改图形请改脚本再跑一遍。\n'
        '     图形定义在 108 的方格里，整组缩到中间 %(pct)d%%：自适应图标只露中间 66，\n'
        '     缩放后图形正好落在安全区里，圆形/方形遮罩都切不到。 -->\n'
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:width="108dp"\n'
        '    android:height="108dp"\n'
        '    android:viewportWidth="108"\n'
        '    android:viewportHeight="108">\n'
        '  <group\n'
        '      android:scaleX="%(s).2f"\n'
        '      android:scaleY="%(s).2f"\n'
        '      android:translateX="%(t).2f"\n'
        '      android:translateY="%(t).2f">\n'
        '%(body)s\n'
        '  </group>\n'
        '</vector>\n'
        % {"pct": int(SAFE_SCALE * 100), "s": SAFE_SCALE, "t": SAFE_SHIFT,
           "body": "\n".join(body)})


def background_xml():
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!-- 由 scripts/make_icon.py 生成：蓝底渐变，和儿童桌面同一个色 -->\n'
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    xmlns:aapt="http://schemas.android.com/aapt"\n'
        '    android:width="108dp"\n'
        '    android:height="108dp"\n'
        '    android:viewportWidth="108"\n'
        '    android:viewportHeight="108">\n'
        '  <path android:pathData="M0,0h108v108h-108z">\n'
        '    <aapt:attr name="android:fillColor">\n'
        '      <gradient\n'
        '          android:type="linear"\n'
        '          android:startX="54"\n'
        '          android:startY="0"\n'
        '          android:endX="54"\n'
        '          android:endY="108">\n'
        '        <item android:offset="0" android:color="%s" />\n'
        '        <item android:offset="1" android:color="%s" />\n'
        '      </gradient>\n'
        '    </aapt:attr>\n'
        '  </path>\n'
        '</vector>\n' % (hexof(BLUE_TOP), hexof(BLUE_BOT)))


ADAPTIVE_XML = (
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '  <background android:drawable="@drawable/ic_launcher_background" />\n'
    '  <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
    '</adaptive-icon>\n')

MIPMAPS = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    print(path)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "preview"
    if mode == "preview":
        for key, fn in DESIGNS.items():
            write_png(os.path.join(OUT, "icon-%s.png" % key), 384,
                      render(384, raster(fn()), ss=2,
                             mask=pred(rrect(0, 0, 1, 1, 0.21))))
            print(os.path.join(OUT, "icon-%s.png" % key))
        return

    key = (sys.argv[2] if len(sys.argv) > 2 else "a").lower()
    layers = DESIGNS[key]()

    # API 26+ 走自适应图标（系统按自己的遮罩裁），API 24/25 和部分桌面临时用的还是这张 PNG：
    # 圆角要自己带，图形按整格画（更大方），两边的观感才对得上
    corner = pred(rrect(0, 0, 1, 1, 0.21))
    for name, size in MIPMAPS.items():
        write_png(os.path.join(RES, "mipmap-%s" % name, "ic_launcher.png"),
                  size, render(size, raster(layers), ss=4, mask=corner))
        print(os.path.join(RES, "mipmap-%s" % name, "ic_launcher.png"))

    write(os.path.join(RES, "drawable", "ic_launcher_background.xml"), background_xml())
    write(os.path.join(RES, "drawable", "ic_launcher_foreground.xml"), foreground_xml(layers))
    write(os.path.join(RES, "mipmap-anydpi-v26", "ic_launcher.xml"), ADAPTIVE_XML)


if __name__ == "__main__":
    main()
