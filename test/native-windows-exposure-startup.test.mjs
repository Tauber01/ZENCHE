import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);
const read = async (path) => readFile(new URL(path, root), "utf8");

const methodBody = (source, startSignature, nextSignature) => {
  const start = source.indexOf(startSignature);
  const end = source.indexOf(nextSignature, start);
  assert.ok(start >= 0 && end > start, `应找到 ${startSignature}`);
  return source.slice(start, end);
};

test("Windows: 曝光模式初始化事件不得提前访问尚未加载的参数控件", async () => {
  const [xaml, source] = await Promise.all([
    read("native/windows/MainWindow.xaml"),
    read("native/windows/MainWindow.xaml.cs"),
  ]);
  assert.match(
    source,
    /private bool _initializing = true;/,
    "初始化门禁必须在 InitializeComponent 运行前开启",
  );

  const exposureModePosition = xaml.indexOf('x:Name="ExposureModeBox"');
  const shutterPosition = xaml.indexOf('x:Name="ShutterBox"');
  assert.ok(exposureModePosition >= 0, "应找到曝光模式控件");
  assert.ok(shutterPosition > exposureModePosition, "快门控件在曝光模式控件之后加载");
  const exposureControl = xaml.slice(exposureModePosition, shutterPosition);
  assert.match(
    exposureControl,
    /SelectionChanged="ExposureModeBox_SelectionChanged"/,
    "曝光模式控件应连接启动时触发的事件处理器",
  );
  assert.match(
    exposureControl,
    /Tag="manual"[^>]*IsSelected="True"/,
    "曝光模式应保留会在 XAML 加载期触发事件的预选项",
  );

  const handler = methodBody(
    source,
    "private async void ExposureModeBox_SelectionChanged",
    "private void VideoShutterModeBox_SelectionChanged",
  );
  const initializationGuard = handler.indexOf("if (_initializing)");
  const availabilityUpdate = handler.indexOf("UpdateExposureAvailability();");
  assert.ok(initializationGuard >= 0, "事件处理器应显式短路 XAML 初始化阶段");
  assert.ok(availabilityUpdate >= 0, "事件处理器应在正常交互时刷新参数可用性");
  assert.ok(
    initializationGuard < availabilityUpdate,
    "必须先短路 InitializeComponent 触发的 SelectionChanged，再访问其余参数控件",
  );
  assert.match(
    handler.slice(initializationGuard, availabilityUpdate),
    /if \(_initializing\)\s*\{\s*return;\s*\}/s,
    "初始化短路应立即返回",
  );
});

test("Windows: 参数预选事件不得在初始化期刷新依赖后置控件的读数", async () => {
  const [xaml, source] = await Promise.all([
    read("native/windows/MainWindow.xaml"),
    read("native/windows/MainWindow.xaml.cs"),
  ]);

  const shutterPosition = xaml.indexOf('x:Name="ShutterBox"');
  const aperturePosition = xaml.indexOf('x:Name="ApertureBox"');
  assert.ok(shutterPosition >= 0, "应找到快门控件");
  assert.ok(aperturePosition > shutterPosition, "光圈控件在快门控件之后加载");
  const shutterControl = xaml.slice(shutterPosition, aperturePosition);
  assert.match(
    shutterControl,
    /SelectionChanged="ParameterBox_SelectionChanged"/,
    "快门控件应连接共享参数事件处理器",
  );
  assert.match(
    shutterControl,
    /Tag="0\.008"[^>]*IsSelected="True"/,
    "快门控件应保留会在 XAML 加载期触发事件的预选项",
  );

  const handler = methodBody(
    source,
    "private async void ParameterBox_SelectionChanged",
    "private async void ExposureModeBox_SelectionChanged",
  );
  const initializationGuard = handler.indexOf("if (_initializing)");
  const readoutUpdate = handler.indexOf("UpdateExposureReadout();");
  assert.ok(initializationGuard >= 0, "共享参数处理器应显式短路 XAML 初始化阶段");
  assert.ok(readoutUpdate >= 0, "正常交互时应刷新曝光读数");
  assert.ok(
    initializationGuard < readoutUpdate,
    "必须先短路 InitializeComponent 触发的 SelectionChanged，再读取其余参数控件",
  );
  assert.match(
    handler.slice(initializationGuard, readoutUpdate),
    /if \(_initializing\)\s*\{\s*return;\s*\}/s,
    "初始化短路应立即返回",
  );
});

test("Windows: 视频快门模式初始化事件不得提前配置尚未加载的快门控件", async () => {
  const [xaml, source] = await Promise.all([
    read("native/windows/MainWindow.xaml"),
    read("native/windows/MainWindow.xaml.cs"),
  ]);

  const videoModePosition = xaml.indexOf('x:Name="VideoShutterModeBox"');
  const shutterPosition = xaml.indexOf('x:Name="ShutterBox"');
  assert.ok(videoModePosition >= 0, "应找到视频快门模式控件");
  assert.ok(shutterPosition > videoModePosition, "快门控件在视频快门模式控件之后加载");
  const videoModeControl = xaml.slice(videoModePosition, shutterPosition);
  assert.match(
    videoModeControl,
    /SelectionChanged="VideoShutterModeBox_SelectionChanged"/,
    "视频快门模式控件应连接启动时触发的事件处理器",
  );
  assert.match(
    videoModeControl,
    /Tag="angle"[^>]*IsSelected="True"/,
    "视频快门模式应保留会在 XAML 加载期触发事件的预选项",
  );

  const handler = methodBody(
    source,
    "private void VideoShutterModeBox_SelectionChanged",
    "private async void VideoCodecBox_SelectionChanged",
  );
  const initializationGuard = handler.indexOf("if (_initializing)");
  const shutterConfiguration = handler.indexOf("ConfigureShutterControl(_videoMode);");
  assert.ok(initializationGuard >= 0, "事件处理器应显式短路 XAML 初始化阶段");
  assert.ok(shutterConfiguration >= 0, "正常交互时应重新配置快门控件");
  assert.ok(
    initializationGuard < shutterConfiguration,
    "必须先短路 InitializeComponent 触发的 SelectionChanged，再配置快门控件",
  );
  assert.match(
    handler.slice(initializationGuard, shutterConfiguration),
    /if \(_initializing\)\s*\{\s*return;\s*\}/s,
    "初始化短路应立即返回",
  );

  const constructor = methodBody(
    source,
    "public MainWindow()",
    "private void ApplyResponsiveEditorLayout",
  );
  const componentInitialization = constructor.indexOf("InitializeComponent();");
  const completeTreeConfiguration = constructor.indexOf("ConfigureShutterControl(false);");
  const initializationFinished = constructor.indexOf("_initializing = false;");
  assert.ok(
    componentInitialization >= 0 && completeTreeConfiguration > componentInitialization,
    "完整 XAML 树加载后仍应配置初始快门状态",
  );
  assert.ok(
    initializationFinished > completeTreeConfiguration,
    "构造器应在初始快门状态配置完成后再结束初始化门禁",
  );
});
