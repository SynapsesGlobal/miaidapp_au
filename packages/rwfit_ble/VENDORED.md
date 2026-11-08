# rwfit_ble（vendored 副本）

RWFIT 智能戒指 BLE Flutter 插件，来源 <https://github.com/RWFitSDK/RW_flutter_plugin>。

- 上游版本：v0.0.10 之后一个提交 `be17a8f`（`v0.0.10-1-gbe17a8f`，2026-10-27，
  含解绑后丢弃旧设备事件的原生修复）。原生 SDK：Android `com.rwfit:blesdk-rwfit:2.261012`
  （`android/repo` 本地 maven），iOS `DHBleSDK.xcframework`（`ios/Frameworks`）。
- 去掉了 `example/`、`.github/`、上游 `analysis_options.yaml` / `CLAUDE.md`。
- 文档：`doc/integration_guide_zh.md` / `doc/integration_guide_en.md`（上游原文）。

## 为什么不用 git 依赖

本项目 Flutter 3.19.6 / Dart 3.3.4，上游插件无法直接引用，需要两处补丁（详见仓库
`docs/smart_ring_feasibility.md`）：

1. **`pubspec.yaml`**：`environment.sdk` 从 `^3.12.0` 放宽为 `'>=3.3.0 <4.0.0'`，
   `flutter_lints` 从 `^6.0.0` 降为 `^3.0.0`。插件 Dart 代码只用到 Dart 3.0 语法。
2. **`android/build.gradle(.kts)`**：上游是 Kotlin DSL，Flutter 3.19 的 Gradle 插件只认
   `build.gradle`，kts 会被静默跳过并导致 `package com.rwfit.rwfit_ble does not exist`。
   已等价改写为 Groovy 的 `android/build.gradle` / `android/settings.gradle`。

## App 侧配套配置

- `pubspec.yaml`：`rwfit_ble: { path: packages/rwfit_ble }`
- `android/build.gradle`：`allprojects.repositories` 加
  `maven { url "${project(':rwfit_ble').projectDir}/repo" }`
- `android/app/build.gradle`：`minSdkVersion 24`
- `ios/Runner/Info.plist`：`NSBluetoothAlwaysUsageDescription` / `NSBluetoothPeripheralUsageDescription`
- Android 12+ 运行时申请 `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT`（见 `lib/services/smart_ring_service.dart`）

## 升级步骤

1. `git clone https://github.com/RWFitSDK/RW_flutter_plugin` 到临时目录，切到目标 tag。
2. 删掉本目录，重新拷贝（排除 `example/`、`.github/`、`.git/`）。
3. 重新应用上面两处补丁：改 `pubspec.yaml`，删 `*.gradle.kts` 并按新版内容重写 Groovy 版。
4. 更新本文件的版本号，`flutter pub get` 后两端各编译一次。

CN 版（`miaidapp_cn`）接入时复制本目录即可，两端保持同一版本。
