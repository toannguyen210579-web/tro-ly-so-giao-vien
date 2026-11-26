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
	<string>Dùng máy ảnh để quét giấy tờ, chụp ảnh thẻ, chụp đề, chụp văn bản sang Word, chụp trang ghi chép họp, chụp trang cần dịch, chụp minh chứng và quét thẻ Giơ thẻ.</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>Chọn ảnh có sẵn để quét thành PDF, làm ảnh thẻ, lưu minh chứng, gửi đề cần giải, hỏi Trợ lý, lấy ghi chép họp, dịch tài liệu và đọc thẻ Giơ thẻ.</string>
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

# Tệp app lưu (PDF quét, bảng lương, bộ thẻ, minh chứng xuất…) hiện trong ứng dụng Tệp của iPhone, iPad:
# Trên iPhone › Trợ lý số GV (thầy cô báo 24/11/2026 chưa có chỗ lưu tệp).
if ! grep -q UIFileSharingEnabled "$PLIST"; then
  /usr/bin/env python3 - "$PLIST" <<'PY'
import sys
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
i=s.rfind('</dict>'); s=s[:i]+'\t<key>UIFileSharingEnabled</key>\n\t<true/>\n\t<key>LSSupportsOpeningDocumentsInPlace</key>\n\t<true/>\n'+s[i:]
open(p,'w',encoding='utf-8').write(s)
PY
fi

# Bản iPhone: khai không dùng mã hóa đặc biệt (app chỉ dùng HTTPS) để khỏi khai lại mỗi lần
# tải bản mới lên App Store Connect.
if ! grep -q ITSAppUsesNonExemptEncryption "$PLIST"; then
  /usr/bin/env python3 - "$PLIST" <<'PY'
import sys
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
i=s.rfind('</dict>'); s=s[:i]+'\t<key>ITSAppUsesNonExemptEncryption</key>\n\t<false/>\n'+s[i:]
open(p,'w',encoding='utf-8').write(s)
PY
fi
# Chạy trên iPhone, iPad và máy Mac chip Apple (chốt 24/11/2026, thay cách "chỉ iPhone" ngày 22/11).
# flutter create mặc định TARGETED_DEVICE_FAMILY = "1,2"; iPad phải cho xoay đủ 4 chiều
# (đa nhiệm trên iPad), nếu thiếu thì Apple từ chối bản tải lên.
/usr/bin/env python3 - "$PLIST" <<'PY'
import sys, re
p='ios/Runner.xcodeproj/project.pbxproj'
s=open(p,encoding='utf-8').read()
s=s.replace('TARGETED_DEVICE_FAMILY = 1;','TARGETED_DEVICE_FAMILY = "1,2";')
open(p,'w',encoding='utf-8').write(s)
q=sys.argv[1]; t=open(q,encoding='utf-8').read()
du='''	<key>UISupportedInterfaceOrientations~ipad</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationPortraitUpsideDown</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
'''
t=re.sub(r'\t<key>UISupportedInterfaceOrientations~ipad</key>\s*<array>.*?</array>\n', '', t, flags=re.S)
i=t.rfind('</dict>'); t=t[:i]+du+t[i:]
open(q,'w',encoding='utf-8').write(t)
PY

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
# Flutter mới đòi các thư viện biên dịch với Android API 36 trở lên; vài plugin (file_picker…) còn để 34.
# Nâng compileSdk của các plugin lên 36 khi đóng gói (không đổi minSdk, máy cũ vẫn cài được).
G=android/build.gradle.kts
if [ -f "$G" ] && ! grep -q "compileSdkVersion\"(36)" "$G"; then
  cat >> "$G" <<'K'

subprojects {
    val nangSdk: Project.() -> Unit = {
        extensions.findByName("android")?.withGroovyBuilder { "compileSdkVersion"(36) }
    }
    if (state.executed) nangSdk() else afterEvaluate { nangSdk() }
}
K
fi
# Tên hiện dưới biểu tượng trên màn hình điện thoại
/usr/bin/env python3 - <<'PY'
import re
p='android/app/src/main/AndroidManifest.xml'
s=open(p,encoding='utf-8').read()
s=re.sub(r'android:label="[^"]*"','android:label="Trợ lý số GV"',s,count=1)
open(p,'w',encoding='utf-8').write(s)
p='ios/Runner/Info.plist'
s=open(p,encoding='utf-8').read()
s=re.sub(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)',r'\g<1>Trợ lý số GV\g<2>',s)
open(p,'w',encoding='utf-8').write(s)
PY
# Thông báo nhắc hạn (flutter_local_notifications): quyền, bộ nhận lịch nhắc, desugaring.
if [ -f "$MF" ] && ! grep -q POST_NOTIFICATIONS "$MF"; then
  /usr/bin/env python3 - "$MF" <<'PY'
import sys
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
s=s.replace('<application', '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n    <application', 1)
rc='''        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    </application>'''
s=s.replace('    </application>', rc, 1)
open(p,'w',encoding='utf-8').write(s)
PY
fi
G=android/app/build.gradle.kts
if [ -f "$G" ] && ! grep -q "isCoreLibraryDesugaringEnabled" "$G"; then
  /usr/bin/env python3 - "$G" <<'PY'
import sys
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
s=s.replace('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true', 1)
s=s.rstrip()+'\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
open(p,'w',encoding='utf-8').write(s)
PY
fi

# Ký bản release bằng khóa thử nghiệm cố định (tool/khoa_thu.jks) để cài đè được các bản sau.
# Trước khi đưa lên Google Play sẽ thay bằng khóa tải lên chính thức.
G=android/app/build.gradle.kts
if [ -f "$G" ] && [ -f tool/khoa_thu.jks ] && ! grep -q 'create("release")' "$G"; then
  cp tool/khoa_thu.jks android/app/khoa_thu.jks
  /usr/bin/env python3 - "$G" "$(cat tool/khoa_thu.matkhau)" <<'PY'
import sys
p, pw = sys.argv[1], sys.argv[2]
s = open(p, encoding='utf-8').read()
cfg = f"""    signingConfigs {{
        create("release") {{
            storeFile = file("khoa_thu.jks")
            storePassword = "{pw}"
            keyAlias = "upload"
            keyPassword = "{pw}"
        }}
    }}

    buildTypes {{"""
s = s.replace("    buildTypes {", cfg, 1)
s = s.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("release")')
open(p, 'w', encoding='utf-8').write(s)
PY
fi
echo "Da chuan bi xong."

# ML Kit nhận chữ: chỉ dùng bộ chữ Latin, báo R8 bỏ qua các bộ chữ không cài.
cat >> android/app/proguard-rules.pro <<'P'
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
P
