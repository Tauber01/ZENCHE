# Nikon 原生术语与功能映射

本表以 Nikon EXPEED 6 / 7 机型的简体中文参考指南为命名基准。界面只有在实际
控制相机机身时使用 Nikon 菜单术语；本地监看处理和 iPhone/iPad 系统视频能力会
明确标注，避免伪装成机身功能。

| 界面术语 | 对应功能 | USB/PTP 映射 | 备注 |
| --- | --- | --- | --- |
| 快门速度 | 设置照片曝光时间 | `0x500D ExposureTime` | P、A 模式下由相机控制 |
| 光圈 | 设置镜头光圈值 | `0x5007 FNumber` | P、S 模式下由相机控制 |
| ISO感光度 | 设置照片 ISO 感光度 | `0x500F ExposureIndex` | 可用范围取决于机型和拍摄状态 |
| 曝光补偿 | 调整自动曝光结果 | `0x5010 ExposureBiasCompensation` | M 模式下不作为快门或光圈控制 |
| 对焦模式 | `AF-S 单次AF`、`AF-C 连续AF`、`MF 手动对焦` | `0x500A FocusMode`；实时取景回退 `0xD061` | Nikon 值：AF-S `0x8010`、AF-C `0x8011`、MF `0x0001`；实时取景回退值为 `0/1/4` |
| 白平衡 | `自动`或`手动预设` | `0x5005 WhiteBalance` | 自动 `0x0002`；Nikon 手动预设 `0x8013` |
| 拍摄模式 | `P 程序自动`、`S 快门优先自动`、`A 光圈优先自动`、`M 手动` | `0x500E ExposureProgramMode` | P/S/A/M 分别映射为 `2/4/3/1` |
| M · B门 | M 模式下选择 B门快门速度并由应用计时结束曝光 | `ExposureProgramMode=M` + `ExposureTime=0xFFFFFFFF` | B门不是独立拍摄模式 |
| 设定优化校准 | 自动、标准、自然、鲜艳、单色、人像、风景、平面 | Nikon `0xD200 Active Picture Control` | 映射值 `8/1/2/3/4/5/6/7` |
| 实时取景 | 读取相机实时取景帧 | Nikon Start/Get/End Live View | 当前 PTP 返回 JPEG 帧 |
| 条纹图案（本地） | 在监看画面叠加加亮显示 | 本地像素处理 | 不写入机身的 `g15 条纹图案` |
| 监看 LUT（本地） | 对监看画面应用 `.cube` LUT | 本地颜色处理 | 不改变原片或机身优化校准 |
| 本地 2× 超采样 | 对实时取景帧进行本地高质量缩放 | 本地像素处理 | 不等同于机身视频菜单的 `扩展过采样` |
| 监看显示尺寸 | 设置本地预览输出尺寸 | 本地缩放 | 不等同于机身的 `画面尺寸/帧频` |
| 实时取景格式 | 显示 PTP 预览帧格式 | JPEG | 不等同于机身的 `视频文件类型` |

## iOS / iPadOS 边界

iOS/iPadOS 使用 AVFoundation 控制本机或 UVC 视频设备，因此采用“采集画面尺寸/
帧频”“输出编码偏好”“本机镜头变焦”等系统视频术语。它们不是 Nikon PTP
机身控制，也不会在界面中显示为 Nikon 的“视频文件类型”“高分辨率数字变焦”
或“扩展过采样”。

## 官方术语来源

- [Z8 对焦](https://onlinemanual.nikonimglib.com/z8/zh-cn/focus_31.html)
- [Z8 曝光与长时间曝光](https://onlinemanual.nikonimglib.com/z8/zh-cn/exposure_32.html)
- [Z8 ISO感光度](https://onlinemanual.nikonimglib.com/z8/zh-cn/iso_sensitivity_34.html)
- [Z8 白平衡](https://onlinemanual.nikonimglib.com/z8/zh-cn/white_balance_35.html)
- [Z8 优化校准](https://onlinemanual.nikonimglib.com/z8/zh-cn/picture_controls_37.html)
- [Z8 视频画面尺寸和帧频](https://onlinemanual.nikonimglib.com/z8/zh-cn/video_frame_size_and_rate_options_41.html)
- [Z8 自定义设定菜单](https://onlinemanual.nikonimglib.com/z8/zh-cn/20_custom_settings_menu_198.html)
- [libgphoto2 Nikon PTP 映射](https://github.com/gphoto/libgphoto2/tree/master/camlibs/ptp2)
