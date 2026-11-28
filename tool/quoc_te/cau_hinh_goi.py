"""Đặt cấu hình đóng gói cho bản quốc tế: tên hiển thị, mã gói riêng, câu xin quyền tiếng Anh.
Chạy sau khi tool/chuan_bi.sh đã tạo thư mục android, ios (gọi từ chuan_bi.sh khi QUOC_TE=true)."""
import os
import re

ten = 'TeachDesk'  # người dùng chọn 28/11/2026; App Store đã giữ tên (Apple ID 6840301876)

p = 'ios/Runner/Info.plist'
if os.path.exists(p):
    s = open(p, encoding='utf-8').read()
    cau = {
        'NSCameraUsageDescription': 'The camera is used to scan documents, take ID photos and read answer cards.',
        'NSPhotoLibraryUsageDescription': 'Photos you choose are used to make PDFs, ID photos and to read answer cards.',
        'NSMicrophoneUsageDescription': 'The microphone is used only when you turn on a voice feature.',
        'NSSpeechRecognitionUsageDescription': 'Speech recognition is used only when you turn on a voice feature.',
    }
    for k, v in cau.items():
        s = re.sub(r'(<key>' + k + r'</key>\s*<string>)[^<]*(</string>)', lambda m, v=v: m.group(1) + v + m.group(2), s)
    s = re.sub(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)', lambda m: m.group(1) + ten + m.group(2), s)
    open(p, 'w', encoding='utf-8').write(s)

p = 'ios/Runner.xcodeproj/project.pbxproj'
if os.path.exists(p):
    s = open(p, encoding='utf-8').read()

    def them(m):
        goc, duoi = m.group(1), m.group(2) or ''
        return m.group(0) if goc.endswith('.intl') else 'PRODUCT_BUNDLE_IDENTIFIER = ' + goc + '.intl' + duoi + ';'

    s = re.sub(r'PRODUCT_BUNDLE_IDENTIFIER = ([A-Za-z0-9.]+?)(\.RunnerTests)?;', them, s)
    open(p, 'w', encoding='utf-8').write(s)

p = 'android/app/src/main/AndroidManifest.xml'
if os.path.exists(p):
    s = open(p, encoding='utf-8').read()
    s = re.sub(r'android:label="[^"]*"', 'android:label="' + ten + '"', s, count=1)
    open(p, 'w', encoding='utf-8').write(s)

for p in ('android/app/build.gradle.kts', 'android/app/build.gradle'):
    if os.path.exists(p):
        s = open(p, encoding='utf-8').read()

        def doi(m):
            return m.group(0) if m.group(2).endswith('.intl') else m.group(1) + m.group(2) + '.intl' + m.group(3)

        s = re.sub(r'(applicationId\s*=?\s*")([A-Za-z0-9_.]+)(")', doi, s, count=1)
        open(p, 'w', encoding='utf-8').write(s)
        tim = re.search(r'applicationId\s*=?\s*"([^"]+)"', s)
        print('Ma goi Android:', tim.group(1) if tim else 'khong thay')

# Biểu tượng riêng của TeachDesk (tool/quoc_te/ve_bieu_tuong.py)
p = 'pubspec.yaml'
s = open(p, encoding='utf-8').read()
s = s.replace('assets/icon/app_icon.png', 'assets/icon/teachdesk_icon.png')
s = s.replace('assets/icon/app_icon_foreground.png', 'assets/icon/teachdesk_icon_foreground.png')
s = s.replace('adaptive_icon_background: "#FFFFFF"', 'adaptive_icon_background: "#5B3FDC"')
open(p, 'w', encoding='utf-8').write(s)

print('Da dat cau hinh ban quoc te:', ten)
