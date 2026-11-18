#!/usr/bin/env bash
# Tạo các thư mục android/ios (nếu chưa có) và khai báo quyền máy ảnh, ảnh.
set -euo pipefail
flutter create --org vn.vietnamtieudiem --project-name tro_ly_so_giao_vien --platforms=android,ios .
# flutter create sinh sẵn test mẫu không hợp với app, bỏ đi
rm -f test/widget_test.dart

PLIST=ios/Runner/Info.plist
if ! grep -q NSCameraUsageDescription "$PLIST"; then
  /usr/bin/env python3 - "$PLIST" <<'PY'
import sys
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
them='''	<key>NSCameraUsageDescription</key>
	<string>Dùng máy ảnh để quét giấy tờ và chụp ảnh thẻ.</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>Chọn ảnh có sẵn để làm ảnh thẻ.</string>
'''
i=s.rfind('</dict>'); s=s[:i]+them+s[i:]
open(p,'w',encoding='utf-8').write(s)
PY
fi

if [ -f ios/Podfile ]; then
  sed -i.bak -E "s/^#? *platform :ios.*/platform :ios, '15.5'/" ios/Podfile && rm -f ios/Podfile.bak
fi

for G in android/app/build.gradle android/app/build.gradle.kts; do
  if [ -f "$G" ]; then
    sed -i.bak -E 's/minSdk( =|) *flutter\.minSdkVersion/minSdk\1 21/' "$G" && rm -f "$G.bak"
  fi
done
echo "Da chuan bi xong."
