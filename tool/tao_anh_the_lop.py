# Tạo ảnh "cả lớp giơ thẻ": 27 thẻ QR (thiếu thẻ số 15), mỗi thẻ xoay theo đáp án em chọn.
import random, qrcode
from PIL import Image, ImageDraw, ImageFont, ImageFilter
random.seed(7)
F = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 46)
Fs = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 22)
# đáp án: A 4, B 17, C 4, D 2 (27 em), thẻ 15 không giơ
so = [i for i in range(1, 29) if i != 15]
dap = ['B'] * 17 + ['A'] * 4 + ['C'] * 4 + ['D'] * 2
random.shuffle(dap)
xoay = {'A': 0, 'B': 90, 'C': 180, 'D': -90}   # PIL: dương = ngược chiều kim đồng hồ
def the(n):
    W = 360
    c = Image.new('RGB', (W, W), 'white'); d = ImageDraw.Draw(c)
    q = qrcode.QRCode(border=0, box_size=10, error_correction=qrcode.constants.ERROR_CORRECT_M)
    q.add_data(f'VNTD-GT:{n}'); q.make()
    qi = q.make_image(fill_color='black', back_color='white').convert('RGB').resize((230, 230), Image.NEAREST)
    c.paste(qi, ((W - 230) // 2, (W - 230) // 2))
    def chu(t, goc, x, y):
        im = Image.new('RGBA', (60, 60), (0, 0, 0, 0)); ImageDraw.Draw(im).text((30, 30), t, font=F, fill='black', anchor='mm')
        im = im.rotate(goc, expand=True); c.paste(im, (x - im.width // 2, y - im.height // 2), im)
    chu('A', 0, W // 2, 34); chu('C', 180, W // 2, W - 34); chu('D', -90 + 180, 34, W // 2); chu('B', 90 - 180, W - 34, W // 2)
    d.text((W - 10, W - 6), str(n), font=Fs, fill='#666', anchor='rb')
    return c
nen = Image.new('RGB', (2900, 1900), '#c9c2b6'); dn = ImageDraw.Draw(nen)
for y in range(0, 1900, 4):
    v = 190 + int(20 * y / 1900); dn.line([(0, y), (2900, y)], fill=(v, v - 6, v - 16))
k = 0
ket = {}
for r in range(4):
    for col in range(7):
        if k >= len(so): break
        n, a = so[k], dap[k]; k += 1
        ket[n] = a
        im = the(n).rotate(xoay[a] + random.uniform(-6, 6), expand=True, fillcolor=(0, 0, 0))
        m = Image.new('L', the(n).size, 255).rotate(xoay[a] + random.uniform(0, 0), expand=True)
        x = 90 + col * 400 + random.randint(-25, 25); y = 70 + r * 450 + random.randint(-20, 20)
        msk = Image.new('L', im.size, 0); msk.paste(255, (0, 0, im.width, im.height))
        # bóng đổ nhẹ
        nen.paste((120, 112, 100), (x + 10, y + 12, x + im.width + 10, y + im.height + 12))
        nen.paste(im, (x, y))
nen = nen.filter(ImageFilter.GaussianBlur(0.6))
nen.save('anh_the_lop.jpg', quality=88)
print(sorted(ket.items()))
from collections import Counter; print(Counter(ket.values()))
# Bản nhúng vào bài chụp màn hình: thu nhỏ, đen trắng cho nhẹ, rồi mã hóa base64 vào integration_test/chup_clip_anh_the.dart
nho = Image.open('anh_the_lop.jpg').convert('L').resize((2320, 1520), Image.LANCZOS)
nho.save('anh_nho.jpg', quality=82, optimize=True)
