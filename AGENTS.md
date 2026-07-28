# Nikon Link 项目约定

- 每次完成任何功能、修复、界面或资源更新后，都必须自动重新打包三个平台的安装产物：
  - macOS：DMG
  - Android：APK
  - iOS / iPadOS：IPA
- 默认运行 `./scripts/build-all.sh`，并验证生成产物及其 SHA-256 校验文件。
- 如果本机具备有效的 Apple Developer 签名条件，生成签名 IPA；否则生成 unsigned IPA，并在交付结果中明确说明签名状态及无法生成签名包的原因。
- 任一平台构建失败时，不得静默跳过；应继续验证其他平台，并在最终交付中逐项报告 DMG、APK、IPA 的成功或失败状态。
- 最终回复应提供所有成功生成产物的可点击绝对路径。
- 所有新增功能和产品界面必须使用三端原生技术栈实现：macOS 使用 SwiftUI /
  AppKit，Android 使用原生 Android SDK，iOS / iPadOS 使用 SwiftUI 及系统框架。
  禁止使用 Web、PWA、WebView、HTML、CSS 或 JavaScript 作为功能实现或安装包运行
  时依赖。仓库现有 Web / PWA 仅作历史演示，不得继续扩展，除非用户明确另行授权。
