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
	<key>NSMicrophoneUsageDescription</key>
	<string>Dùng micro để chuyển lời nói thành chữ.</string>
	<key>NSSpeechRecognitionUsageDescription</key>
	<string>Nhận giọng nói để ghi thành văn bản.</string>
'''
i=s.rfind('</dict>'); s=s[:i]+them+s[i:]
open(p,'w',encoding='utf-8').write(s)
PY
fi

if [ -f ios/Podfile ]; then
  sed -i.bak -E "s/^#? *platform :ios.*/platform :ios, '15.5'/" ios/Podfile && rm -f ios/Podfile.bak
fi

# Android: quyền micro và khai báo bộ nhận giọng, bộ đọc văn bản (bắt buộc từ Android 11).
MF=android/app/src/main/AndroidManifest.xml
if [ -f "$MF" ] && ! grep -q RECORD_AUDIO "$MF"; then
  /usr/bin/env python3 - "$MF" <<'PY'
import sys
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
s=s.replace('<application', '<uses-permission android:name="android.permission.RECORD_AUDIO"/>\n    <uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
them='''        <intent>
            <action android:name="android.speech.RecognitionService"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
'''
if '<queries>' in s:
    s=s.replace('<queries>', '<queries>\n'+them, 1)
else:
    s=s.replace('</manifest>', '    <queries>\n'+them+'    </queries>\n</manifest>', 1)
open(p,'w',encoding='utf-8').write(s)
PY
fi

for G in android/app/build.gradle android/app/build.gradle.kts; do
  if [ -f "$G" ]; then
    sed -i.bak -E 's/minSdk( =|) *flutter\.minSdkVersion/minSdk\1 21/' "$G" && rm -f "$G.bak"
  fi
done
# Lint của Android bị lỗi nội bộ khi phân tích plugin image_picker (NoSuchMethodError),
# không liên quan mã của app: tắt bước lintVital khi đóng gói bản release.
for G in android/build.gradle.kts android/build.gradle; do
  if [ -f "$G" ] && ! grep -q "lintVital" "$G"; then
    if [[ "$G" == *.kts ]]; then
      printf '\nsubprojects {\n    tasks.matching { it.name.contains("lintVital") }.configureEach { enabled = false }\n}\n' >> "$G"
    else
      printf '\nsubprojects {\n    tasks.matching { it.name.contains("lintVital") }.configureEach { enabled = false }\n}\n' >> "$G"
    fi
  fi
done
echo "Da chuan bi xong."
