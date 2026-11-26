"""Dựng lại ảnh cửa hàng khổ 1080×1920 (cua-hang/anh/man_hinh_0X.png) từ ảnh chụp app mới (26/11/2026).

Giữ nền, khung máy của ảnh cũ; đặt ảnh chụp mới vào màn hình máy, thêm thanh trạng thái kiểu iPhone và vạch vuốt
(giống ghep_anh1.py). Có hai dòng chữ thì vẽ lại tiêu đề: dòng 1 trắng (Be Vietnam Pro SemiBold 61),
dòng 2 vàng (ExtraBold 78), nền chỗ tiêu đề nội suy từ hai mép ảnh.
Chạy: python3 dung_anh_iphone.py man_hinh_cu.png anh_chup.png ra.png ["Dòng 1" "Dòng 2"]
Sau đó: tao_anh_co.py 1206 2622 iphone_63 để ra ảnh App Store 6,3 inch.
"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

nen, chup, ra = sys.argv[1:4]
dong = sys.argv[4:6]
PHONG = '/home/claude/fonts/'
base = Image.open(nen).convert('RGB')

if len(dong) == 2:
    # nền chỗ tiêu đề: mỗi hàng nội suy giữa mép trái và mép phải (nền là dải màu chéo)
    m = np.asarray(base).astype(float)
    cao = 425
    trai, phai = m[:cao, 4, :], m[:cao, -5, :]
    t = np.linspace(0, 1, m.shape[1])[None, :, None]
    dai = trai[:, None, :] * (1 - t) + phai[:, None, :] * t
    vung = Image.fromarray(dai.clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))
    base.paste(vung, (0, 0))
    d = ImageDraw.Draw(base)
    f1 = ImageFont.truetype(PHONG + 'BeVietnamPro-SemiBold.ttf', 61)
    f2 = ImageFont.truetype(PHONG + 'BeVietnamPro-ExtraBold.ttf', 78)
    for chu, f, tren, mau in ((dong[0], f1, 124, (241, 245, 250)), (dong[1], f2, 196, (255, 224, 102))):
        b = f.getbbox(chu)
        d.text(((1080 - (b[2] - b[0])) // 2 - b[0], tren - b[1]), chu, font=f, fill=mau)

shot = Image.open(chup).convert('RGB')
x0, y0, x1, y1 = 168, 449, 912, 1832   # vùng màn hình trong khung máy
W, H = x1 - x0, y1 - y0
s = shot.resize((W, round(shot.height * W / shot.width)), Image.LANCZOS)
tren = 50                                 # thanh trạng thái
if s.height > H - tren:                   # ảnh chụp dài hơn màn máy: cắt bớt phần trên cùng để giữ thanh dưới
    s = s.crop((0, 0, W, H - tren))
du = H - s.height
duoi = du - tren                          # vạch vuốt về màn hình chính
man = Image.new('RGB', (W, H), shot.getpixel((5, 5)))
man.paste(s, (0, tren))
d = ImageDraw.Draw(man)
d.rectangle((0, tren + s.height, W, H), fill=shot.getpixel((shot.width // 2, shot.height - 3)))
f = ImageFont.truetype('/usr/share/fonts/opentype/inter/Inter-SemiBold.otf', 26)
d.text((58, 36), '9:41', font=f, fill=(20, 20, 20), anchor='lm')
bx, by = W - 92, 26
d.rounded_rectangle((bx, by, bx + 44, by + 21), radius=6, outline=(20, 20, 20), width=2)
d.rounded_rectangle((bx + 4, by + 4, bx + 36, by + 17), radius=3, fill=(20, 20, 20))
d.rounded_rectangle((bx + 46, by + 7, bx + 50, by + 14), radius=2, fill=(20, 20, 20))
for i in range(4):                        # vạch sóng
    h = 8 + i * 4
    d.rounded_rectangle((W - 160 + i * 9, by + 21 - h, W - 154 + i * 9, by + 21), radius=2, fill=(20, 20, 20))
if duoi >= 8:
    pw = 250
    d.rounded_rectangle(((W - pw) // 2, H - duoi // 2 - 4, (W + pw) // 2, H - duoi // 2 + 4), radius=4, fill=(20, 20, 20))
mask = Image.new('L', (W, H), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, W - 1, H - 1), radius=36, fill=255)
base.paste(man, (x0, y0), mask)
base.save(ra, optimize=True)
