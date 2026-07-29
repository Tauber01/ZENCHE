# Windows 构建与 USB 驱动

Windows 版是原生 WPF 应用，不使用 WebView。它通过 `libusb-1.0.dll` 直接实现
Nikon Vendor PTP 会话，包含相机识别、实时取景、SDRAM 拍摄、曝光/对焦/白平衡
控制、本地图库和前台 FTP/PASV、HTTP、WebDAV 收件箱。

## 环境

- Windows 11 x64 或 ARM64
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- 与目标架构一致的官方
  [libusb 1.0](https://github.com/libusb/libusb/releases) Windows DLL
- [NSIS 3](https://nsis.sourceforge.io/Download)
- PowerShell 7 或 Windows PowerShell 5.1

从 libusb 官方发布压缩包选择对应架构的 `libusb-1.0.dll`。x64 构建通常使用
`MS64/dll/libusb-1.0.dll`；不要混用 32 位 DLL。

## 打包

在仓库根目录运行：

```powershell
.\scripts\build-windows.ps1 `
  -Runtime win-x64 `
  -LibUsbDll C:\path\to\libusb-1.0.dll
```

也可以设置环境变量：

```powershell
$env:NIKONLINK_LIBUSB_DLL = "C:\path\to\libusb-1.0.dll"
.\scripts\build-windows.ps1
```

输出：

```text
dist/ZENCHE-0.8.3-Windows-x64-Setup.exe
dist/ZENCHE-0.8.3-Windows-x64-Setup.exe.sha256
dist/ZENCHE-0.8.3-Windows-x64.zip
dist/ZENCHE-0.8.3-Windows-x64.zip.sha256
```

`Setup.exe` 是默认交付物，安装到 `Program Files\帧澈 ZENCHE`，创建开始菜单和
桌面快捷方式，并注册到 Windows“已安装的应用”以支持卸载和覆盖升级。ZIP
保留为便携版。两者默认都是自包含 .NET 发布；传入 `-FrameworkDependent`
可减小包体，但目标电脑必须安装 .NET 8 Desktop Runtime。

当前社区安装包未使用代码签名证书，Windows SmartScreen 可能在首次运行时提示
“未知发布者”。正式分发前应使用受信任的代码签名证书签署应用和安装程序。

## Nikon USB 接口

Windows 默认可能把 PTP 接口交给系统相机驱动，libusb 无法直接声明该接口。需要
为 Nikon 相机的 Still Image/PTP 接口绑定 WinUSB 或 libusbK（例如使用 Zadig）。
只修改 PTP 接口，不要修改同一设备的存储、音频或其他接口。

更换驱动可能令 NX Tether、Camera Control Pro 或系统照片导入暂时无法识别相机。
测试结束后可在“设备管理器”中卸载该设备驱动，再重新扫描硬件以恢复系统驱动。

连接前关闭会占用相机的 Nikon 软件。Windows 版会严格匹配 Nikon Vendor ID
`0x04b0` 和项目支持的 Product ID，不会把其他 USB 设备当作受支持相机。

诊断日志保存在 `%LOCALAPPDATA%\帧澈 ZENCHE\Logs`，按日写入、单文件 5 MB
滚动并保留 14 天。“无线传输”页面可打开日志目录，或打开带最近脱敏日志的
GitHub Issue 预填页面。

## 验收

1. 在干净的 x64/ARM64 目标主机运行 `Setup.exe`，确认安装、启动、覆盖升级和
   “已安装的应用”卸载均正常。
2. 验证缺少 DLL、USB 权限和驱动冲突时均显示可操作的错误。
3. 按 [相机实机验收清单](CAMERA_TEST_CHECKLIST.md) 验证连接、取景、参数和拍摄。
4. 在可信局域网内验证端口 `2121` 的 PASV 上传以及端口 `8080` 的 HTTP/WebDAV
   上传，并在应用退出后确认全部端口关闭。

当前仓库不提交 libusb 二进制文件；打包者需自行从官方发行版取得 DLL，并遵守
[第三方许可说明](../THIRD_PARTY_NOTICES.md)。
