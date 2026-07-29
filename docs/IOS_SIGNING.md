# iOS 签名与发布

## 本地生成可安装 IPA

需要完整 Xcode、有效的 Apple Developer 证书，以及与
`com.tauber.nikonlink.ios` 匹配的描述文件。先在 Xcode 中打开
`native/ios/NikonLink.xcodeproj`，确认 Team 和真机可用，再运行：

```sh
IOS_DEVELOPMENT_TEAM=你的TeamID ./scripts/build-ios.sh --signed
```

手动签名时：

```sh
IOS_DEVELOPMENT_TEAM=你的TeamID \
IOS_PROFILE_SPECIFIER="描述文件名称" \
IOS_SIGNING_IDENTITY="Apple Development" \
./scripts/build-ios.sh --signed
```

结果为 `dist/NikonLink-0.7.2-ios-signed.ipa`，并附带 SHA-256 校验文件。

## GitHub Actions

仓库的 `Build signed iOS package` 手动工作流使用以下 Actions secrets：

- `IOS_CERTIFICATE_P12_BASE64`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_KEYCHAIN_PASSWORD`
- `IOS_DEVELOPMENT_TEAM`
- `IOS_SIGNING_IDENTITY`（通常为 `Apple Development`）

证书和描述文件应只放在加密 secrets 中，不能提交到仓库。运行工作流时可填写
已有 Release 标签，签名 IPA 会同时作为工作流产物和 Release asset 上传。

普通 `Build` 与标签 `Release` 工作流只生成名称带 `unsigned` 的校验包。未签名
IPA 不能安装到真机，也不能冒充正式安装包。

## Nikon USB/PTP 说明

iPadOS 的公开 AVFoundation 接口可以发现兼容的外接 UVC 视频设备，但不提供
通用 USB/PTP 厂商控制。Z9、Z8、Z f、Z6III、Z50II、Z5II 与 ZR 的快门、
光圈、ISO 和原图下载只有在 Nikon 提供 iOS 协议授权或官方 SDK 后才能接入；
当前 iOS 界面会如实标记这一能力边界。
