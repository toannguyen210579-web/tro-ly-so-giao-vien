import sys, json
from PIL import Image
P = [[91,313,405],[91,309,405],[88,313,405],[91,293,405],[96,309,405],[89,313,405],[83,313,405],[99,309,405]]
srcs = ['/home/claude/anh/man_hinh_01_moi.png'] + [f'/home/claude/repo/tlgv/cua-hang/anh/man_hinh_0{i}.png' for i in range(2, 9)]
W, H, ten = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
fp = []
for i, (src, (a, b, c)) in enumerate(zip(srcs, P), 1):
    img = Image.open(src).convert('RGB'); w, h = img.size
    s = W / w; y = lambda v: round(v * s)
    extra = H - y(h); e1 = int(extra * 0.5); e2 = extra - e1
    big = img.resize((W, y(h)), Image.LANCZOS)
    parts = []
    for y0, y1, add in [(0, a, e1), (a, b, 0), (b, c, e2), (c, h, 0)]:
        p = big.crop((0, y(y0), W, y(y1)))
        if add: p = p.resize((W, p.height + add), Image.BICUBIC)
        parts.append(p)
    out = Image.new('RGB', (W, H)); yy = 0
    for p in parts: out.paste(p, (0, yy)); yy += p.height
    assert yy == H
    out.save(f'/mnt/user-data/outputs/anh_iphone/{ten}_{i:02d}.png', optimize=True)
    sm = out.resize((4, 12), Image.BOX)
    fp.append([list(sm.getpixel((x, r))) for r in range(12) for x in range(4)])
json.dump(fp, open(f'/home/claude/anh/fp_{ten}.json', 'w'))
print('xong', ten)
