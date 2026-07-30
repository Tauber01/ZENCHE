# HarmonyOS 构建与部署

HarmonyOS 版使用 Stage 模型和 ArkUI 原生组件，不使用 WebView。USB 路径直接调用
`usbManager`，实现 Nikon Vendor PTP 相机识别、实时取景、SDRAM 拍摄和常用参数
控制；应用私有目录提供本地图库，前台可开启 FTP/PASV、HTTP 和 WebDAV 收件箱。

## 环境

- DevEco Studio 6.0.1 或更高版本（Apple Silicon 使用 Mac ARM 安装包）
- HarmonyOS SDK；项目兼容与目标基线均为 `5.0.0(12)` / API 12，
  可使用 DevEco Studio 6.0.1 自带的 API 21 SDK 编译
- 支持 USB Host 的 HarmonyOS NEXT 真机
- 已配置的应用签名和调试/发布证书

模拟器不能替代 Nikon USB Host 和局域网无线传输实机验收。

## DevEco Studio

1. 在 DevEco Studio 打开 `native/harmony`。
2. 等待 ohpm 与 Hvigor 同步完成。
3. 在 Project Structure 中配置应用签名；包名为
   `com.tauber.nikonlink`。
4. 选择 `entry` 模块和 API 12 或更高的兼容 SDK。
5. 连接真机，授予系统显示的 USB 访问权限后运行。

命令行构建脚本会自动检测 `/Applications/DevEco-Studio.app` 和
`~/Applications/DevEco-Studio.app`，并使用 Studio 自带的 Node、JBR、SDK 与
Hvigor：

```sh
./scripts/build-harmony.sh
```

也可以显式指定其他 Hvigor：

```sh
NIKONLINK_HVIGORW=/path/to/hvigorw ./scripts/build-harmony.sh
```

输出：

```text
dist/ZENCHE-1.1.0-HarmonyOS.hap
dist/ZENCHE-1.1.0-HarmonyOS.hap.sha256
```

未配置 `signingConfigs` 时，Hvigor 会生成可用于编译验证的未签名 HAP；真机安装
和发布前，需要在 DevEco Studio 中关联华为开发者证书与 Profile 后重新构建。

## 权限与行为

- `ohos.permission.INTERNET`：前台 FTP/PASV、HTTP 和 WebDAV 收件箱。
- `ohos.permission.GET_WIFI_INFO`：显示相机需要连接的局域网 IPv4 地址。
- USB 设备访问：连接时由 `usbManager.requestRight` 请求，不预先静默取得。

单次 HarmonyOS USB bulk 调用限制在 200 KB 以下，因此 PTP 数据面使用 192 KB
分块并重新组装完整容器。FTP 控制端口是 `2121`，被动数据端口是 `2122`，
HTTP/WebDAV 端口是 `8080`；只应在可信局域网临时开启。三个入口使用同一组
`nikonlink` 用户名和密码，HTTP/WebDAV 通过 Basic Auth 校验。

应用离开页面时停止实时取景、断开 USB 并关闭全部无线监听。图库文件保存在应用
私有目录，卸载应用会一并删除。

诊断日志保存在应用沙盒的 `files/logs`，按日写入、单文件 5 MB 滚动并保留
14 天。“诊断日志”页面可打开带最近脱敏日志的 GitHub Issue 预填页面。

## 验收

1. 在手机、平板和 2-in-1 的窄/宽窗口验证导航、预览和参数区。
2. 对每个支持机型验证 USB 授权、拔插、接口占用和超时恢复。
3. 按 [相机实机验收清单](CAMERA_TEST_CHECKLIST.md) 验证实时取景、参数和 SDRAM
   拍摄下载。
4. 从相机使用 FTP 上传 JPEG、NEF、HEIF/HEIC 与 TIFF，再从局域网设备使用
   HTTP PUT 和 WebDAV PUT 上传，验证接收中断不会生成空文件。

未安装 DevEco/HarmonyOS SDK 的主机只能执行资源、结构和静态检查，不能证明 HAP
可签名安装或 USB 厂商命令已通过特定固件验收。
