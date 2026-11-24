import sys
from PIL import Image, ImageDraw, ImageFont
nen, chup, ra = sys.argv[1:4]
base = Image.open(nen).convert('RGB')
shot = Image.open(chup).convert('RGB')
x0, y0, x1, y1 = 168, 449, 912, 1832   # vùng màn hình trong khung máy
W, H = x1 - x0, y1 - y0
s = shot.resize((W, round(shot.height * W / shot.width)), Image.LANCZOS)
du = H - s.height
tren = 50                                 # thanh trạng thái
duoi = du - tren                          # vạch vuốt về màn hình chính
man = Image.new('RGB', (W, H), shot.getpixel((5, 5)))
man.paste(s, (0, tren))
d = ImageDraw.Draw(man)
d.rectangle((0, tren + s.height, W, H), fill=shot.getpixel((540, shot.height - 3)))
# giờ và pin, kiểu thanh trạng thái iPhone
f = ImageFont.truetype('/usr/share/fonts/opentype/inter/Inter-SemiBold.otf', 26)
d.text((58, 36), '9:41', font=f, fill=(20, 20, 20), anchor='lm')
bx, by = W - 92, 26
d.rounded_rectangle((bx, by, bx + 44, by + 21), radius=6, outline=(20, 20, 20), width=2)
d.rounded_rectangle((bx + 4, by + 4, bx + 36, by + 17), radius=3, fill=(20, 20, 20))
d.rounded_rectangle((bx + 46, by + 7, bx + 50, by + 14), radius=2, fill=(20, 20, 20))
for i in range(4):                        # vạch sóng
    h = 8 + i * 4
    d.rounded_rectangle((W - 160 + i * 9, by + 21 - h, W - 154 + i * 9, by + 21), radius=2, fill=(20, 20, 20))
pw = 250
d.rounded_rectangle(((W - pw) // 2, H - duoi // 2 - 4, (W + pw) // 2, H - duoi // 2 + 4), radius=4, fill=(20, 20, 20))
mask = Image.new('L', (W, H), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, W - 1, H - 1), radius=36, fill=255)
base.paste(man, (x0, y0), mask)
base.save(ra, optimize=True)
