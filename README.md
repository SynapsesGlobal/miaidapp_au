# MiAid

## Getting Started

## API code generation

When the API is updated, please [download the latest swagger file](https://miaid.sandbox19.preview.cx/manage/docs/api) under `miaid_api.swagger` then generate the flutter api code:

```install the package
flutter pub build
```

flutter pub get

```SH

flutter packages pub run build_runner build --delete-conflicting-outputs

flutter packages pub run build_runner watch --delete-conflicting-outputs
```

```SH
flutter pub run intl_utils:generate
```

## Build APK for sandbox

Sandbox (test) builds install as a separate app: package `com.em.bright.miaid.test`, named "MiAid(Test)".

```SH
flutter build apk -t lib/main_sandbox.dart --flavor google_sandbox
```

## Build IPA for sandbox

Sandbox (test) builds use bundle ID `com.em.bright.ios.dev.miaid` (shared with dev), named "MiAid(Test)".

```SH
flutter build ipa -t lib/main_sandbox.dart --flavor sandbox
```

## Build APK for Huawei sandbox

This build doesn't use Google services and uses Huawei Push notifications
 
```SH
flutter build apk -t lib/main_sandbox_huawei.dart --flavor huawei
```

keytool -genkey -keystore huawei-keystore.jks -storepass "k23spf4WF5Uf4qLx" -alias upload -keypass "Z4udhXK9kHHAz9qp" -keysize 2048 -keyalg RSA -validity 36500
keytool -export -rfc -keystore huawei-keystore.jks -alias upload -file huawei_upload_certificate.pem

keytool -keypasswd -keystore huawei-keystore.jks -alias upload -storepass "k23spf4WF5Uf4qLx" -keypass "Z4udhXK9kHHAz9qp" -new "Z4udhXK9kHHAz9qp"

## Build APK or AppBundle for prod

```SH


```

```SH
flutter build apk -t lib/main_prod.dart --flavor google_prod
flutter build appbundle -t lib/main_prod.dart --flavor google_prod

use Xcode13.4.1
open /Applications/Xcode_13.4.1.app/Contents/MacOS/Xcode

open ios/Runner.xcworkspace
xcodebuild -version
flutter build ipa -t lib/main_prod.dart --flavor prod

open build/ios/archive/Runner.xcarchive/
```

```SH
rm -Rf ios/Pods
rm -Rf ios/.symlinks
rm -Rf ios/Flutter/Flutter.framework
rm -Rf ios/Flutter/Flutter.podspec
pod deintegrate
pod install
```

```

Gavin updated 2023-05-08
new update flutter version 3.7.12
xcode:14.3
CocoaPods version 1.12.1


android:
Platform android-33, build-tools 34.0.0-rc3
Android Studio (version 2022.2)
garadle:7.2.0
distributionUrl=https\://services.gradle.org/distributions/gradle-7.5-bin.zip

```

```
Gavin updated 2023-08-29
new update flutter verion 3.13.1

```

```
Replace
/.pub-cache/hosted/pub.dev/country_code_picker-3.0.0/flags/tw.png
to
/miaid-f/assets/icons/tw.png

Edit
/.pub-cache/hosted/pub.dev/country_code_picker-3.0.0/lib/src/i18n/zh.json
中国台湾省 -> 中国台湾
香港 -> 中国香港
澳门 -> 中国澳门
```
```
var sharedPreferences = await SharedPreferences.getInstance();
await sharedPreferences.setString('video-call-source', 'chatbot');
await sharedPreferences.setString('chatbot-id', chatbotId);
用于标识video是由哪发起的，如果为home说明是从首页发起的此时不需要传chatbotid，如果是chatbot说明是从chatbot发起的
此时需要传chatbotId用于后端创建与chatbot关联的call

具体传参是在call_screen_store.dart的startNewCall函数处理。
```
开启location tracker监听，需要配置：
1.Info.plist
<key>UIBackgroundModes</key>
<array>
<string>location</string>
<string>fetch</string>
<string>processing</string>
</array>

<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.em.bright.miaid.refresh</string>
</array>

2.AndroidManifest.xml
<service
android:name="id.flutter.flutter_background_service.BackgroundService"
android:foregroundServiceType="location"
android:exported="false"
tools:replace="android:exported" />

<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />

```
设置位置
澳大利亚：xcrun simctl loccation booted set -33.8688,151.2093
中国：xcrun simctl location booted set 39.9042,116.4074

启动命令（连上模拟器或真机后）：
android启动测试：
flutter run --flavor google_sandbox -t lib/main_sandbox.dart -d <设备ID>

android打包测试：
flutter build apk -t lib/main_sandbox.dart --flavor google_sandbox

android启动正式：
flutter run --flavor google_prod -d <设备ID>

android打包正式：
flutter build apk --flavor google_prod

ios启动测试
flutter run --flavor sandbox -t lib/main_sandbox.dart -d <设备ID>

ios启动正式
flutter run --flavor prod -d  flutter run --flavor google_prod -d <设备ID>
```


