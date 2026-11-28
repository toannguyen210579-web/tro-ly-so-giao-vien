"""Điền hồ sơ App Store Connect cho TeachDesk từ cua-hang/TEACHDESK_HO_SO_KHO.md bằng khóa API.

Chạy lại nhiều lần được. KHÔNG gửi duyệt. Việc nào Apple từ chối thì in cảnh báo rồi làm tiếp việc khác,
cuối cùng liệt kê tình trạng. Thông tin liên hệ cho người duyệt chép từ app bản Việt (không ghi trong kho mã).
"""
import json, os, re, sys, time, urllib.error, urllib.parse, urllib.request
import jwt

KEY = os.environ["ASC_KEY_P8"]
KID, ISS = os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"]
APP, APP_VN = os.environ["APP_ID"], os.environ["APP_ID_VN"]
PHIEN_BAN = os.environ.get("PHIEN_BAN", "1.0.0")
BASE = "https://api.appstoreconnect.apple.com"
canh_bao = []


def bao(m):
    print(f"::notice title=TeachDesk::{m}")


def token():
    now = int(time.time())
    return jwt.encode({"iss": ISS, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      KEY, algorithm="ES256", headers={"kid": KID, "typ": "JWT"})


def api(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method,
                                 headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, {"raw": raw.decode("utf-8", "replace")[:500]}


def loi(js):
    return "; ".join(f"{x.get('code')}: {x.get('detail')}" for x in js.get("errors", [])) or str(js)[:300]


def thu(st, js, viec):
    """Trả True nếu được; không được thì ghi cảnh báo và làm tiếp."""
    if st in (200, 201, 204):
        bao(f"Xong: {viec}")
        return True
    canh_bao.append(f"{viec}: HTTP {st} {loi(js)}")
    print(f"::warning title=TeachDesk::{viec}: HTTP {st} {loi(js)}")
    return False


# ---------- Đọc hồ sơ ----------
hs = open("cua-hang/TEACHDESK_HO_SO_KHO.md", encoding="utf-8").read()


def muc(tieu_de, het="\n#"):
    a = hs.index(tieu_de)
    a = hs.index("\n", a) + 1
    b = hs.find(het, a)
    return hs[a:b if b > 0 else len(hs)].strip()


phu_de = re.search(r"\| Dòng phụ App Store[^|]*\| ([^|]+) \|", hs).group(1).strip()
quang_ba = muc("### Văn bản quảng bá App Store")
tu_khoa = muc("### Từ khóa App Store")
mo_ta = muc("### Mô tả đầy đủ", "\n## ")
ghi_chu = muc("## C. Ghi chú cho người duyệt", "\n## ")
URL_RT = "https://trolysogiaovien.com/teachdesk/privacy/"
URL_HT = "https://trolysogiaovien.com/teachdesk/support/"
for ten, chu, toi_da in (("phụ đề", phu_de, 30), ("quảng bá", quang_ba, 170), ("từ khóa", tu_khoa, 100),
                         ("mô tả", mo_ta, 4000), ("ghi chú", ghi_chu, 4000)):
    if not chu or len(chu) > toi_da:
        print(f"::error::{ten}: {len(chu)} ký tự (tối đa {toi_da})"); sys.exit(1)
bao(f"Hồ sơ: phụ đề {len(phu_de)}, quảng bá {len(quang_ba)}, từ khóa {len(tu_khoa)}, mô tả {len(mo_ta)}, ghi chú {len(ghi_chu)}")

# ---------- App ----------
st, js = api("GET", f"/v1/apps/{APP}?fields[apps]=name,bundleId,sku,primaryLocale,contentRightsDeclaration")
if st != 200:
    print(f"::error::Không đọc được app {APP}: HTTP {st} {loi(js)}"); sys.exit(1)
a = js["data"]["attributes"]
bao(f"App {a['name']} · {a['bundleId']} · {a['sku']} · {a['primaryLocale']}")
if a["bundleId"] != "vn.vietnamtieudiem.troLySoGiaoVien.intl":
    print("::error::Sai app, dừng"); sys.exit(1)

if a.get("contentRightsDeclaration") != "DOES_NOT_USE_THIRD_PARTY_CONTENT":
    st, r = api("PATCH", f"/v1/apps/{APP}", {"data": {"type": "apps", "id": APP, "attributes": {
        "contentRightsDeclaration": "DOES_NOT_USE_THIRD_PARTY_CONTENT"}}})
    thu(st, r, "Khai quyền nội dung: không dùng nội dung bên thứ ba")

# ---------- Thông tin app: phụ đề, chính sách, danh mục ----------
st, js = api("GET", f"/v1/apps/{APP}/appInfos?limit=5")
info = None
if thu(st, js, "Đọc thông tin app") and js["data"]:
    info = js["data"][0]
    st, r = api("PATCH", f"/v1/appInfos/{info['id']}", {"data": {"type": "appInfos", "id": info["id"], "relationships": {
        "primaryCategory": {"data": {"type": "appCategories", "id": "EDUCATION"}},
        "secondaryCategory": {"data": {"type": "appCategories", "id": "PRODUCTIVITY"}}}}})
    thu(st, r, "Danh mục Education, phụ Productivity")
    st, r = api("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations?limit=50")
    if thu(st, r, "Đọc bản chữ thông tin app"):
        for l in r["data"]:
            if l["attributes"]["locale"] == "en-US":
                st2, r2 = api("PATCH", f"/v1/appInfoLocalizations/{l['id']}", {"data": {
                    "type": "appInfoLocalizations", "id": l["id"],
                    "attributes": {"subtitle": phu_de, "privacyPolicyUrl": URL_RT}}})
                thu(st2, r2, f"Phụ đề \"{phu_de}\" và địa chỉ chính sách quyền riêng tư")

# ---------- Phân loại tuổi ----------
if info:
    st, r = api("GET", f"/v1/appInfos/{info['id']}/ageRatingDeclaration")
    if thu(st, r, "Đọc phân loại tuổi") and r.get("data"):
        ar = r["data"]
        muc_do = ["alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated", "gunsOrOtherWeapons",
                  "medicalOrTreatmentInformation", "profanityOrCrudeHumor", "sexualContentGraphicAndNudity",
                  "sexualContentOrNudity", "horrorOrFearThemes", "matureOrSuggestiveThemes",
                  "violenceCartoonOrFantasy", "violenceRealisticProlongedGraphicOrSadistic", "violenceRealistic"]
        co_khong = ["gambling", "unrestrictedWebAccess", "lootBox", "advertising", "ageAssurance",
                    "healthOrWellnessTopics", "messagingAndChat", "parentalControls", "userGeneratedContent"]
        co = set(ar["attributes"].keys())
        tl = {k: "NONE" for k in muc_do if k in co}
        tl.update({k: False for k in co_khong if k in co})
        la = sorted(co - set(muc_do) - set(co_khong))
        if la:
            bao("Mục phân loại tuổi chưa trả lời bằng API: " + ", ".join(la))
        st, r2 = api("PATCH", f"/v1/ageRatingDeclarations/{ar['id']}", {"data": {
            "type": "ageRatingDeclarations", "id": ar["id"], "attributes": tl}})
        thu(st, r2, f"Phân loại tuổi: trả lời Không cho {len(tl)} mục")

# ---------- Trang phiên bản ----------
st, js = api("GET", f"/v1/apps/{APP}/appStoreVersions?filter[platform]=IOS&limit=5")
ver = None
if thu(st, js, "Đọc trang phiên bản") and js["data"]:
    ver = js["data"][0]
    va = ver["attributes"]
    bao(f"Phiên bản {va.get('versionString')}: {va.get('appVersionState') or va.get('appStoreState')}")
    st, r = api("PATCH", f"/v1/appStoreVersions/{ver['id']}", {"data": {"type": "appStoreVersions", "id": ver["id"],
               "attributes": {"versionString": PHIEN_BAN, "copyright": "2026 Nguyễn Văn Toàn", "releaseType": "MANUAL"}}})
    thu(st, r, f"Số phiên bản {PHIEN_BAN}, bản quyền, phát hành thủ công")
    st, r = api("GET", f"/v1/appStoreVersions/{ver['id']}/appStoreVersionLocalizations?limit=50")
    if thu(st, r, "Đọc bản mô tả"):
        for l in r["data"]:
            if l["attributes"]["locale"] == "en-US":
                st2, r2 = api("PATCH", f"/v1/appStoreVersionLocalizations/{l['id']}", {"data": {
                    "type": "appStoreVersionLocalizations", "id": l["id"],
                    "attributes": {"description": mo_ta, "keywords": tu_khoa, "promotionalText": quang_ba,
                                   "supportUrl": URL_HT, "marketingUrl": "https://trolysogiaovien.com/"}}})
                thu(st2, r2, "Mô tả, từ khóa, quảng bá, địa chỉ hỗ trợ (en-US)")

    # Thông tin cho người duyệt: chép liên hệ từ app bản Việt
    lh = None
    st, r = api("GET", f"/v1/apps/{APP_VN}/appStoreVersions?filter[platform]=IOS&limit=1")
    if st == 200 and r["data"]:
        st, r = api("GET", f"/v1/appStoreVersions/{r['data'][0]['id']}/appStoreReviewDetail")
        if st == 200 and r.get("data"):
            x = r["data"]["attributes"]
            lh = {k: x.get(k) for k in ("contactFirstName", "contactLastName", "contactPhone", "contactEmail")}
    tt = dict(lh or {})
    tt.update({"demoAccountRequired": False, "notes": ghi_chu})
    st, r = api("GET", f"/v1/appStoreVersions/{ver['id']}/appStoreReviewDetail")
    if st == 200 and r.get("data"):
        st, r = api("PATCH", f"/v1/appStoreReviewDetails/{r['data']['id']}", {"data": {
            "type": "appStoreReviewDetails", "id": r["data"]["id"], "attributes": tt}})
    else:
        st, r = api("POST", "/v1/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails", "attributes": tt,
                    "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver["id"]}}}}})
    thu(st, r, "Thông tin cho người duyệt (" + ("có liên hệ" if lh else "CHƯA có liên hệ") + ", ghi chú, không cần đăng nhập)")

# ---------- Giá: miễn phí ----------
st, js = api("GET", f"/v1/apps/{APP}/appPriceSchedule")
if st == 200 and js.get("data"):
    bao("Giá: đã có lịch giá, giữ nguyên")
else:
    st, js = api("GET", f"/v1/apps/{APP}/appPricePoints?filter[territory]=USA&limit=200")
    mp = None
    if thu(st, js, "Đọc bảng giá"):
        for p in js["data"]:
            if float(p["attributes"].get("customerPrice") or 1) == 0:
                mp = p["id"]
                break
    if mp:
        st, r = api("POST", "/v1/appPriceSchedules", {
            "data": {"type": "appPriceSchedules", "relationships": {
                "app": {"data": {"type": "apps", "id": APP}},
                "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                "manualPrices": {"data": [{"type": "appPrices", "id": "${gia}"}]}}},
            "included": [{"type": "appPrices", "id": "${gia}", "attributes": {"startDate": None},
                          "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": mp}}}}]})
        thu(st, r, "Giá: miễn phí (0 USD)")
    else:
        canh_bao.append("Không tìm thấy mức giá 0 USD")

# ---------- Phạm vi: mọi nước ----------
st, js = api("GET", f"/v2/appAvailabilities/{APP}")
if st == 200 and js.get("data"):
    bao("Phạm vi: đã đặt, giữ nguyên")
else:
    st, js = api("GET", "/v1/territories?limit=200")
    if thu(st, js, "Đọc danh sách nước"):
        ids = [t["id"] for t in js["data"]]
        st, r = api("POST", "/v2/appAvailabilities", {
            "data": {"type": "appAvailabilities", "attributes": {"availableInNewTerritories": True}, "relationships": {
                "app": {"data": {"type": "apps", "id": APP}},
                "territoryAvailabilities": {"data": [{"type": "territoryAvailabilities", "id": "${" + t + "}"} for t in ids]}}},
            "included": [{"type": "territoryAvailabilities", "id": "${" + t + "}", "attributes": {"available": True},
                          "relationships": {"territory": {"data": {"type": "territories", "id": t}}}} for t in ids]})
        thu(st, r, f"Phạm vi: {len(ids)} nước và vùng")

# ---------- Đọc lại ----------
if ver:
    st, r = api("GET", f"/v1/appStoreVersions/{ver['id']}?include=appStoreVersionLocalizations,appStoreReviewDetail")
    if st == 200:
        va = r["data"]["attributes"]
        bao(f"ĐỌC LẠI phiên bản {va.get('versionString')} · {va.get('appVersionState') or va.get('appStoreState')} · phát hành {va.get('releaseType')} · {va.get('copyright')}")
        for i in r.get("included", []):
            x = i["attributes"]
            if i["type"] == "appStoreVersionLocalizations":
                bao(f"ĐỌC LẠI {x['locale']}: mô tả {len(x.get('description') or '')}, từ khóa {len(x.get('keywords') or '')}, "
                    f"quảng bá {len(x.get('promotionalText') or '')}, hỗ trợ {x.get('supportUrl')}")
            if i["type"] == "appStoreReviewDetails":
                bao(f"ĐỌC LẠI người duyệt: liên hệ {'có' if x.get('contactEmail') else 'THIẾU'}, ghi chú {len(x.get('notes') or '')} ký tự")
if info:
    st, r = api("GET", f"/v1/appInfos/{info['id']}?include=primaryCategory,secondaryCategory,appInfoLocalizations,ageRatingDeclaration")
    if st == 200:
        x = r["data"]["attributes"]
        rel = r["data"]["relationships"]
        bao(f"ĐỌC LẠI thông tin app: tuổi {x.get('appStoreAgeRating')}, danh mục "
            f"{(rel.get('primaryCategory', {}).get('data') or {}).get('id')} / {(rel.get('secondaryCategory', {}).get('data') or {}).get('id')}")
        for i in r.get("included", []):
            if i["type"] == "appInfoLocalizations":
                y = i["attributes"]
                bao(f"ĐỌC LẠI {y['locale']}: tên {y.get('name')}, phụ đề {y.get('subtitle')}, chính sách {y.get('privacyPolicyUrl')}")
            if i["type"] == "ageRatingDeclarations":
                chua = sorted(k for k, v in i["attributes"].items() if v is None)
                bao("ĐỌC LẠI phân loại tuổi, mục còn trống: " + (", ".join(chua) or "không"))

if canh_bao:
    bao(f"CÒN {len(canh_bao)} VIỆC CHƯA ĐƯỢC: " + " | ".join(canh_bao))
else:
    bao("Mọi việc đều xong. Chưa gửi duyệt.")
