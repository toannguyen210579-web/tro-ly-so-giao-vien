"""Vẽ biểu tượng TeachDesk (hình riêng: mặt bàn trắng, ba ô công cụ màu trên bàn, nền chàm tím).
Chạy: python3 tool/quoc_te/ve_bieu_tuong.py  -> assets/icon/teachdesk_icon.png, teachdesk_icon_foreground.png"""
from PIL import Image, ImageDraw

S = 4  # vẽ lớn rồi thu nhỏ cho mịn
N = 1024 * S


def nen():
    im = Image.new('RGB', (N, N))
    px = im.load()
    a, b = (58, 64, 200), (124, 58, 237)
    d = ImageDraw.Draw(im)
    for y in range(N):
        t = y / (N - 1)
        d.line([(0, y), (N, y)], fill=tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)))
    return im


def hinh(d, k=1.0):
    """Vẽ bàn và ba ô công cụ, thu về giữa theo hệ số k."""
    def P(x, y):
        return (N / 2 + (x - 512) * k * S, N / 2 + (y - 512) * k * S)

    def hop(x0, y0, x1, y1, r, mau):
        d.rounded_rectangle([P(x0, y0), P(x1, y1)], radius=r * k * S, fill=mau)

    # ba ô công cụ đứng trên bàn
    hop(232, 300, 412, 520, 40, (255, 204, 77))    # vàng
    hop(432, 220, 612, 520, 40, (255, 255, 255))   # trắng (cao nhất)
    hop(632, 360, 792, 520, 40, (94, 234, 212))    # xanh ngọc
    # dấu tích trên ô trắng
    d.line([P(478, 372), P(512, 410), P(570, 330)], fill=(88, 60, 220), width=round(34 * k * S), joint='curve')
    for q in (P(478, 372), P(512, 410), P(570, 330)):
        r = 17 * k * S
        d.ellipse([q[0] - r, q[1] - r, q[0] + r, q[1] + r], fill=(88, 60, 220))
    # mặt bàn và hai chân
    hop(152, 548, 872, 632, 42, (255, 255, 255))
    hop(222, 590, 302, 812, 34, (255, 255, 255))
    hop(722, 590, 802, 812, 34, (255, 255, 255))


im = nen()
hinh(ImageDraw.Draw(im))
im.resize((1024, 1024), Image.LANCZOS).save('assets/icon/teachdesk_icon.png')

fg = Image.new('RGBA', (N, N), (0, 0, 0, 0))
hinh(ImageDraw.Draw(fg), k=0.62)
fg.resize((1024, 1024), Image.LANCZOS).save('assets/icon/teachdesk_icon_foreground.png')
print('ok')
