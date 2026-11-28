# Tải ảnh vật liệu thật (Poly Haven, ambientCG qua kho zuujis-cc0) và mô hình KayKit (CC0) vào dự án Unity.
# Cách dùng: python3 tai_tai_nguyen.py <thư mục dự án Unity>
import io
import os
import sys
import urllib.request

from PIL import Image

DU_AN = sys.argv[1]
TEX = os.path.join(DU_AN, "Assets/ThanhCo/Resources/ThanhCo/Tex")
MH = os.path.join(DU_AN, "Assets/GiongPhaThanh/Resources/MoHinh")
os.makedirs(TEX, exist_ok=True)
os.makedirs(MH, exist_ok=True)
RAW = "https://raw.githubusercontent.com/"

POLYHAVEN = {
    "stone_block_wall": "polyhaven-textures-stone-4",
    "stone_pavers": "polyhaven-textures-stone-4",
    "medieval_blocks_05": "polyhaven-textures-stone-2",
    "grey_roof_tiles_02": "polyhaven-textures-stone-2",
    "rock_surface": "polyhaven-textures-stone-3",
    "cobblestone_floor_04": "polyhaven-textures-stone",
    "lacquered_cherry_wood": "polyhaven-textures-wood-2",
    "medieval_wood": "polyhaven-textures-wood-2",
    "japanese_zelkova_bark": "polyhaven-textures-wood-2",
    "clay_plaster": "polyhaven-textures-concrete",
    "clay_roof_tiles_02": "polyhaven-textures-ceramic",
    "thatch_roof_angled": "polyhaven-textures-organic",
}
AMBIENTCG = {"Grass004": "ambientcg-materials-grass", "Ground037": "ambientcg-materials-ground-2"}
LA = {"LeafSet001": "ambientcg-atlases", "LeafSet003": "ambientcg-atlases", "Foliage001": "ambientcg-atlases"}

KAYKIT = "KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/HEAD/addons/kaykit_character_pack_adventures/"
NHAN_VAT = ["Knight", "Barbarian", "Mage", "Rogue", "RogueHooded"]
ANH_NV = ["knight_texture", "barbarian_texture", "mage_texture", "rogue_texture"]
VU_KHI = ["staff", "axe_1handed", "axe_2handed", "crossbow_1handed"]


def tai(url, lan=3):
    for i in range(lan):
        try:
            with urllib.request.urlopen(url, timeout=120) as r:
                return r.read()
        except Exception as e:
            loi = e
    raise RuntimeError("Khong tai duoc " + url + ": " + str(loi))


def luu(tep, du_lieu):
    with open(tep, "wb") as f:
        f.write(du_lieu)


def main():
    dem = 0
    for ten, kho in POLYHAVEN.items():
        goc = RAW + "zuujis-cc0/" + kho + "/HEAD/" + ten + "/1k/" + ten
        luu(os.path.join(TEX, ten + "_diff.jpg"), tai(goc + "_diff_1k.jpg"))
        luu(os.path.join(TEX, ten + "_nor.jpg"), tai(goc + "_nor_gl_1k.jpg"))
        luu(os.path.join(TEX, ten + "_ao.jpg"), tai(goc + "_ao_1k.jpg"))
        dem += 3
    for ten, kho in AMBIENTCG.items():
        goc = RAW + "zuujis-cc0/" + kho + "/HEAD/" + ten + "/1K-JPG/" + ten + "_1K-JPG_"
        luu(os.path.join(TEX, ten + "_diff.jpg"), tai(goc + "Color.jpg"))
        luu(os.path.join(TEX, ten + "_nor.jpg"), tai(goc + "NormalGL.jpg"))
        try:
            luu(os.path.join(TEX, ten + "_ao.jpg"), tai(goc + "AmbientOcclusion.jpg"))
        except RuntimeError:
            pass
        dem += 3
    for ten, kho in LA.items():
        goc = RAW + "zuujis-cc0/" + kho + "/HEAD/" + ten + "/1K-JPG/" + ten + "_1K-JPG_"
        mau = Image.open(io.BytesIO(tai(goc + "Color.jpg"))).convert("RGB")
        try:
            alpha = Image.open(io.BytesIO(tai(goc + "Opacity.jpg"))).convert("L")
        except RuntimeError:
            alpha = mau.convert("L").point(lambda v: 255 if v > 18 else 0)
        mau.putalpha(alpha.resize(mau.size))
        mau.save(os.path.join(TEX, ten + "_rgba.png"))
        dem += 1
    for ten in NHAN_VAT:
        luu(os.path.join(MH, ten + ".fbx"), tai(RAW + KAYKIT + "Characters/fbx/" + ten + ".fbx"))
        dem += 1
    for ten in ANH_NV:
        luu(os.path.join(MH, ten + ".png"), tai(RAW + KAYKIT + "Characters/fbx/" + ten + ".png"))
        dem += 1
    for ten in VU_KHI:
        luu(os.path.join(MH, ten + ".fbx"), tai(RAW + KAYKIT + "Assets/fbx/" + ten + ".fbx"))
        dem += 1
    print("Da tai", dem, "tep")


main()
