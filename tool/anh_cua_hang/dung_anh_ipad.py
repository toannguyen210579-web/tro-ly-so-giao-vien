"""Dựng ảnh App Store iPad 13 inch (2064×2752) từ ảnh chụp app trên máy giả lập iPad Pro 13 inch.

Nền chuyển màu lấy theo ảnh điện thoại cùng số (mép trái, mép phải), tiêu đề hai dòng (trắng, vàng)
phông Be Vietnam Pro, ảnh chụp đặt trong khung máy tính bảng viền tối.
Chạy: python3 dung_anh_ipad.py anh_chup.png man_hinh_0X.png "Dòng 1" "Dòng 2" ra.png
"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

chup, mau, d1, d2, ra = sys.argv[1:6]
FONT = '/home/claude/fonts/BeVietnamPro-ExtraBold.ttf'
W, H = 2064, 2752

# nền: nội suy ngang giữa cột mép trái và cột mép phải của ảnh điện thoại
m = np.asarray(Image.open(mau).convert('RGB')).astype(float)
trai, phai = m[:, 4, :], m[:, -5, :]
ys = np.linspace(0, m.shape[0] - 1, H).astype(int)
t = np.linspace(0, 1, W)[None, :, None]
nen = trai[ys][:, None, :] * (1 - t) + phai[ys][:, None, :] * t
anh = Image.fromarray(nen.clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))
d = ImageDraw.Draw(anh)

# tiêu đề
f1 = ImageFont.truetype('/home/claude/fonts/BeVietnamPro-SemiBold.ttf', 104)
f2 = ImageFont.truetype(FONT, 126)
d.text((W // 2, 245), d1, font=f1, fill=(255, 255, 255), anchor='mm')
d.text((W // 2, 395), d2, font=f2, fill=(255, 224, 102), anchor='mm')

# khung máy tính bảng
HS = 2000
s = Image.open(chup).convert('RGB')
# thanh trạng thái kiểu iPad ở hai mép (vùng nền ngoài cột nội dung): giờ bên trái, pin bên phải
ds = ImageDraw.Draw(s)
k = (30, 34, 42)
ds.text((70, 27), '9:41', font=ImageFont.truetype('/home/claude/fonts/BeVietnamPro-SemiBold.ttf', 30), fill=k, anchor='lm')
bx = s.width - 120
ds.rounded_rectangle((bx, 15, bx + 52, 39), radius=7, outline=k, width=3)
ds.rounded_rectangle((bx + 5, 20, bx + 42, 34), radius=3, fill=k)
ds.rounded_rectangle((bx + 55, 23, bx + 59, 31), radius=2, fill=k)
WS = round(HS * s.width / s.height)
s = s.resize((WS, HS), Image.LANCZOS)
VIEN = 38
fw, fh = WS + 2 * VIEN, HS + 2 * VIEN
x0, y0 = (W - fw) // 2, 600
bong = Image.new('L', (W, H), 0)
ImageDraw.Draw(bong).rounded_rectangle((x0, y0 + 30, x0 + fw, y0 + fh + 30), radius=100, fill=110)
bong = bong.filter(ImageFilter.GaussianBlur(40))
anh.paste(Image.new('RGB', (W, H), (8, 14, 40)), (0, 0), bong)
d = ImageDraw.Draw(anh)
d.rounded_rectangle((x0, y0, x0 + fw, y0 + fh), radius=100, fill=(18, 20, 24))
d.rounded_rectangle((x0 + 3, y0 + 3, x0 + fw - 3, y0 + fh - 3), radius=97, outline=(70, 74, 82), width=3)
mask = Image.new('L', (WS, HS), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, WS - 1, HS - 1), radius=62, fill=255)
anh.paste(s, (x0 + VIEN, y0 + VIEN), mask)
assert anh.size == (W, H)
anh.save(ra, optimize=True)
