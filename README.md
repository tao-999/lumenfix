# LumenFix — Beauty App

面向移动与桌面平台的实时美颜应用。提供相机取景、实时磨皮/美白/瘦脸/大眼/妆容滤镜、背景虚化与贴纸等能力，支持照片与短视频的快速导出。

---

## ✨ 功能特性

- **实时相机预览**：低时延取景，参数调节所见即所得
- **肤质优化**：磨皮（双边/导向滤波）、美白、祛痘、肤色均衡
- **五官美型**：瘦脸/收下巴/大眼/高鼻梁等（人脸关键点驱动）
- **妆容滤镜**：口红、腮红、眼影、睫毛、眉形，可分层叠加与强度调节
- **调色风格**：LUT 滤镜（支持自定义 512×512 LUT PNG，64×64 网格）
- **背景处理**：人像分割实现背景虚化/替换（绿幕/自定义图）
- **贴纸与道具**：基于人脸关键点的动态贴纸跟踪
- **导入导出**：拍照保存、短视频录制与导出（可选 H.264/H.265）
- **跨平台**：Flutter 一套代码，移动端/桌面端/网页端按需适配

> 注：以上为标准能力清单。若仓库当前尚未开启某些模块，请以 `pubspec.yaml` 与 `assets/` 实际内容为准。

---

## 🧰 技术栈

- **语言/框架**：Dart + Flutter
- **图像管线**：OpenGL ES / Metal / WebGL（随平台选择）
- **人脸/分割模型**：TFLite / MediaPipe（人脸关键点、Selfie Segmentation 等）
- **平台桥接**：Flutter Platform Channels 调用原生加速能力
- **资源组织**：`assets/models/`（AI 模型）、`assets/lut/`（LUT）、`assets/stickers/`（贴纸）

---

## 📁 目录结构（示例）

```
assets/
  lut/                # 预置 LUT 滤镜（512x512, 64x64 网格）
  models/             # TFLite/MediaPipe 模型文件
  stickers/           # 动态贴纸资源（序列帧/矢量/JSON 绑定）
lib/
  core/               # 管线/渲染/参数管理
  features/           # 功能模块（beauty, reshape, makeup, bokeh, sticker）
  ui/                 # 页⾯与控件
  services/           # 设备/存储/权限/日志
test/                 # 单元与集成测试
```

> 具体以仓库实际为准。建议在 README 里长期同步关键目录与职责，方便协作。

---

## ⚙️ 环境要求

- **Flutter**：3.x（建议最新稳定版）
- **Android**：SDK 24+（OpenGL ES 3.0）  
  在 `android/app/src/main/AndroidManifest.xml` 添加：
  ```xml
  <uses-permission android:name="android.permission.CAMERA" />
  <uses-permission android:name="android.permission.RECORD_AUDIO" />
  <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>
  ```
- **iOS**：iOS 13+（Metal）  
  在 `ios/Runner/Info.plist` 添加：
  ```xml
  <key>NSCameraUsageDescription</key><string>Camera access for beauty preview</string>
  <key>NSMicrophoneUsageDescription</key><string>Microphone for video recording</string>
  <key>NSPhotoLibraryAddUsageDescription</key><string>Save photos & videos</string>
  ```
- **Web/桌面**：需支持 WebGL/Metal；不同平台的硬件加速依赖以实际实现为准

---

## 🚀 快速开始

```bash
git clone https://github.com/tao-999/lumenfix.git
cd lumenfix

flutter pub get
flutter run                    # 连接真机/模拟器
```

**指定平台：**
```bash
flutter run -d android    # or ios / windows / macos / linux / chrome
```

---

## 🏗️ 构建发布

- **Android APK/AAB**
  ```bash
  flutter build apk        # or: flutter build appbundle
  ```
- **iOS**
  ```bash
  cd ios && pod install && cd ..
  flutter build ios
  ```
- **Windows/macOS/Linux**
  ```bash
  flutter build windows    # or: macos / linux
  ```
- **Web**
  ```bash
  flutter build web
  ```

---

## 🎨 滤镜与参数（约定）

- **LUT**：放置于 `assets/lut/`，推荐 `512x512`，`64x64` 方格；在 `pubspec.yaml` 声明资源后即可被读取。  
- **美颜参数**（示例约定，具体以实现为准）：
  - `smoothness`（0.0–1.0）磨皮
  - `whiten`（0.0–1.0）美白
  - `reshape.faceSlim` / `reshape.eyeEnlarge`（0.0–1.0）
  - `makeup.lip`, `makeup.blush`, `makeup.shadow`（0.0–1.0）
  - `bokeh.enabled`（bool），`bokeh.strength`（0.0–1.0）

> 建议提供一个 `assets/presets/default.json` 作为默认参数预设，便于一键风格切换与回归测试。

---

## 🛡️ 隐私与数据

- 默认 **本地处理**：相机帧在本地完成推理与渲染，不上传云端。
- 若启用在线服务/崩溃收集，请在此处注明并提供关闭开关。

---

## 📚 常见问题（FAQ）

- **预览非常卡顿？**  
  降低相机分辨率；核查是否正确使用 GPU 管线；避免在 UI 线程做重计算。

- **导出颜色偏差？**  
  注意 YUV→RGB 转换、色域配置与 gamma；统一采样与写回流程。

- **iOS 构建失败？**  
  先 `pod repo update && pod install`；确保在 Xcode 中启用 Metal & 相机权限。

- **Web 无法启动相机？**  
  需 HTTPS 或 `localhost`；浏览器权限需人工允许。

---

## 🧪 开发约定

- 代码提交遵循 Conventional Commits（`feat: / fix: / refactor:`）
- 引入新模型/滤镜请更新 `CHANGELOG.md` 与本 README
- 提交前执行：
  ```bash
  flutter analyze
  flutter test
  ```

---

## 🤝 贡献指南

1. Fork 仓库并创建分支：`git checkout -b feature/xxx`  
2. 提交代码：`git commit -m "feat: add xxx"`  
3. 推送并发起 PR，说明变更点与验证方式

---

## 📄 许可证

本项目采用 **MIT License**。
