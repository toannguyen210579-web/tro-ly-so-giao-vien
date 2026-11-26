"""Dựng ảnh nổi bật Google Play 1024×500 theo giao diện bản 0.4.0 (26/11/2026).

Cách chạy: python3 anh_noi_bat.py man_hinh_01.png chup_thu_hai.png ra.png thu_muc_phong
- man_hinh_01.png: ảnh cửa hàng số 1 (1080×1920, có khung máy trang chủ mới), lấy nguyên khung máy.
- chup_thu_hai.png: ảnh chụp màn hình app (1080 rộng, nhánh anh-xem-app), đặt vào khung máy thứ hai.
- thu_muc_phong: thư mục chứa phông Be Vietnam Pro (Google Fonts).
"""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

man1, chup2, ra, phong = sys.argv[1:5]
W, H = 1024, 500


def font(kieu, co):
    return ImageFont.truetype(f"{phong}/BeVietnamPro-{kieu}.ttf", co)


# Nền chuyển xanh dương sang tím (giữ tông ảnh cũ, hợp biểu tượng app)
nen = Image.new("RGB", (W, H))
px = nen.load()
a, b = (24, 92, 196), (88, 60, 190)
for y in range(H):
    for x in range(W):
        t = min(1, max(0, (x * 0.75 + y * 0.6) / (W * 0.75 + H * 0.6)))
        px[x, y] = tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))
# Vầng sáng sau hai máy
sang = Image.new("L", (W, H), 0)
ImageDraw.Draw(sang).ellipse((600, 40, 1010, 470), fill=90)
sang = sang.filter(ImageFilter.GaussianBlur(70))
nen = Image.composite(Image.new("RGB", (W, H), (120, 190, 255)), nen, sang)


def bong(anh, lech=(0, 10), mo=18, dam=110):
    """Bóng đổ mềm theo hình dạng ảnh (dùng kênh alpha)."""
    m = anh.split()[-1].point(lambda v: dam if v > 0 else 0)
    b = Image.new("RGBA", (anh.width + 80, anh.height + 80), (0, 0, 0, 0))
    b.putalpha(Image.new("L", b.size, 0))
    khung = Image.new("L", b.size, 0)
    khung.paste(m, (40 + lech[0], 40 + lech[1]))
    khung = khung.filter(ImageFilter.GaussianBlur(mo))
    den = Image.new("RGBA", b.size, (8, 20, 60, 255))
    den.putalpha(khung)
    return den


# Máy 1: cắt nguyên khung máy trang chủ từ ảnh cửa hàng số 1, bỏ phần nền xanh quanh khung
m1 = Image.open(man1).convert("RGB")
x0, y0, x1, y1 = 148, 428, 932, 1853
khung1 = m1.crop((x0, y0, x1, y1))
mat1 = Image.new("L", khung1.size, 0)
ImageDraw.Draw(mat1).rounded_rectangle((0, 0, khung1.width - 1, khung1.height - 1), radius=58, fill=255)
khung1 = khung1.convert("RGBA")
khung1.putalpha(mat1)


def may(chup, rong_man, cao_man, vien=14, bo=44):
    """Khung máy đen bo góc, màn hình là ảnh chụp (cắt phần trên đủ cao)."""
    s = Image.open(chup).convert("RGB")
    s = s.resize((rong_man, round(s.height * rong_man / s.width)), Image.LANCZOS).crop((0, 0, rong_man, cao_man))
    k = Image.new("RGBA", (rong_man + 2 * vien, cao_man + 2 * vien), (0, 0, 0, 0))
    d = ImageDraw.Draw(k)
    d.rounded_rectangle((0, 0, k.width - 1, k.height - 1), radius=bo + vien, fill=(18, 22, 32, 255))
    mm = Image.new("L", s.size, 0)
    ImageDraw.Draw(mm).rounded_rectangle((0, 0, s.width - 1, s.height - 1), radius=bo, fill=255)
    k.paste(s, (vien, vien), mm)
    return k


khung2 = may(chup2, 744, 1300)
# Thu nhỏ: máy trang chủ cao 430, máy thứ hai thấp hơn một chút, đặt lệch phía sau
cao1 = 440
k1 = khung1.resize((round(khung1.width * cao1 / khung1.height), cao1), Image.LANCZOS)
cao2 = 372
k2 = khung2.resize((round(khung2.width * cao2 / khung2.height), cao2), Image.LANCZOS)

anh = nen.convert("RGBA")
vt2 = (792, 72)
vt1 = (590, 30)
for k, vt in ((k2, vt2), (k1, vt1)):
    b = bong(k)
    anh.alpha_composite(b, (vt[0] - 40, vt[1] - 40))
    anh.alpha_composite(k, vt)

d = ImageDraw.Draw(anh)
trang = (255, 255, 255)
vang = (255, 214, 64)
d.text((46, 92), "Trợ lý số Giáo viên - Một chạm", font=font("Bold", 27), fill=trang)
d.text((44, 140), "Bớt sổ sách,", font=font("ExtraBold", 50), fill=vang)
d.text((44, 200), "thêm giờ cho học trò", font=font("ExtraBold", 50), fill=vang)
f3 = font("Medium", 21)
d.text((46, 290), "Hỏi AI · Nhận xét học sinh · Chấm trắc nghiệm", font=f3, fill=trang)
d.text((46, 322), "Biên bản họp · Dịch tài liệu · Quét PDF", font=f3, fill=trang)
# Không ghi "Miễn phí", giá, xếp hạng: Google Play không cho đưa thông tin giá, khuyến mãi vào ảnh nổi bật.

anh.convert("RGB").save(ra, optimize=True)
print("Đã lưu", ra, anh.size)
