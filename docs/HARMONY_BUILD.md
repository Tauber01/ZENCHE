# HarmonyOS 构建与部署

HarmonyOS 版使用 Stage 模型和 ArkUI 原生组件，不使用 WebView。USB 路径直接调用
`usbManager`，实现 Nikon Vendor PTP 相机识别、实时取景、SDRAM 拍摄和常用参数
控制；应用私有目录提供本地图库，前台可开启 FTP/PASV 收件箱。

## 环境

- DevEco Studio 5.x
- HarmonyOS SDK，项目基线为 `5.0.0(12)` / API 12
- 支持 USB Host 的 HarmonyOS NEXT 真机
- 已配置的应用签名和调试/发布证书

模拟器不能替代 Nikon USB Host 和局域网 FTP 实机验收。

## DevEco Studio

1. 在 DevEco Studio 打开 `native/harmony`。
2. 等待 ohpm 与 Hvigor 同步完成。
3. 在 Project Structure 中配置应用签名；包名为
   `com.tauber.nikonlink`。
4. 选择 `entry` 模块和 API 12 或更高的兼容 SDK。
5. 连接真机，授予系统显示的 USB 访问权限后运行。

命令行构建：

```sh
NIKONLINK_HVIGORW=/path/to/hvigorw ./scripts/build-harmony.sh
```

如果 `hvigorw` 已在 `PATH` 或位于 `native/harmony/hvigorw`，可直接运行：

```sh
./scripts/build-harmony.sh
```

输出：

```text
dist/NikonLink-0.7.0-HarmonyOS.hap
dist/NikonLink-0.7.0-HarmonyOS.hap.sha256
```

## 权限与行为

- `ohos.permission.INTERNET`：前台 FTP/PASV 收件箱。
- `ohos.permission.GET_WIFI_INFO`：显示相机需要连接的局域网 IPv4 地址。
- USB 设备访问：连接时由 `usbManager.requestRight` 请求，不预先静默取得。

单次 HarmonyOS USB bulk 调用限制在 200 KB 以下，因此 PTP 数据面使用 192 KB
分块并重新组装完整容器。FTP 控制端口是 `2121`，被动数据端口是 `2122`；只应在
可信局域网临时开启。

应用离开页面时停止实时取景、断开 USB 并关闭 FTP 监听。图库文件保存在应用私有
目录，卸载应用会一并删除。

诊断日志保存在应用沙盒的 `files/logs`，按日写入、单文件 5 MB 滚动并保留
14 天。“诊断日志”页面可打开带最近脱敏日志的 GitHub Issue 预填页面。

## 验收

1. 在手机、平板和 2-in-1 的窄/宽窗口验证导航、预览和参数区。
2. 对每个支持机型验证 USB 授权、拔插、接口占用和超时恢复。
3. 按 [相机实机验收清单](CAMERA_TEST_CHECKLIST.md) 验证实时取景、参数和 SDRAM
   拍摄下载。
4. 从相机上传 JPEG、NEF、HEIF/HEIC 与 TIFF，验证接收中断不会生成空文件。

未安装 DevEco/HarmonyOS SDK 的主机只能执行资源、结构和静态检查，不能证明 HAP
可签名安装或 USB 厂商命令已通过特定固件验收。
