import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = async (path) => readFile(new URL(path, root), 'utf8');

const XAML = 'native/windows/MainWindow.xaml';
const CODE = 'native/windows/MainWindow.xaml.cs';
const LOCALIZATION = 'native/windows/Localization.cs';

test('windows auth UI: 顶层 checking/login wall 阻断主工作区', async () => {
  const xaml = await read(XAML);
  const code = await read(CODE);

  assert.match(xaml, /x:Name="AuthWall"[\s\S]*Grid\.RowSpan="3"[\s\S]*Panel\.ZIndex="100"/);
  assert.match(xaml, /x:Name="AuthCheckingPanel"[\s\S]*正在验证登录状态…/);
  assert.match(xaml, /x:Name="AuthFormPanel" Visibility="Collapsed"/);
  assert.match(code, /AuthCheckingPanel\.Visibility = Visibility\.Visible;\n\s*AuthFormPanel\.Visibility = Visibility\.Collapsed;/);
  assert.match(code, /var result = await _authService\.MeAsync\(\);/);
  assert.match(code, /result\.IsSuccess \|\| result\.IsOfflineTolerable/);
  assert.match(code, /_authService\.ClearSession\(\);\n\s*ShowAuthForm\(result\.Message\);/);
});

test('windows auth UI: 登录注册双态、验证码 60s 与失败不放行', async () => {
  const xaml = await read(XAML);
  const code = await read(CODE);

  assert.match(xaml, /x:Name="AuthPasswordBox"[\s\S]*AutomationProperties\.Name="密码（至少 8 位）"/);
  assert.match(xaml, /x:Name="AuthErrorText"[\s\S]*AutomationProperties\.LiveSetting="Assertive"/);
  assert.match(code, /_authCodeCountdown = 60;/);
  assert.match(code, /result\.Status == 503 && !result\.IsProtocolError/);
  assert.match(code, /_authCodeRequired = false;/);
  assert.match(code, /if \(result\.IsSuccess\)[\s\S]*await EnterSignedInStateAsync\(\);/);
  assert.match(code, /password\.Length < 8/);
  assert.match(code, /code\.Length != 6/);
});

test('windows auth UI: 窄窗滚动、520 内容上限、44px 控件与键盘链', async () => {
  const xaml = await read(XAML);
  const code = await read(CODE);

  assert.match(xaml, /<ScrollViewer VerticalScrollBarVisibility="Auto"[\s\S]*<Grid MinWidth="320" MinHeight="560">/);
  assert.match(xaml, /<StackPanel Width="520"[\s\S]*MaxWidth="520"/);
  assert.ok((xaml.match(/Height="44"/g) ?? []).length >= 8);
  assert.match(code, /AuthEmailBox_KeyDown[\s\S]*AuthPasswordBox\.Focus\(\);/);
  assert.match(code, /AuthPasswordBox_KeyDown[\s\S]*AuthCodeBox\.Focus\(\);/);
  assert.match(code, /AuthCodeBox_KeyDown[\s\S]*AuthSubmit_Click/);
});

test('windows auth UI: 登出关闭连接态并清本地会话', async () => {
  const xaml = await read(XAML);
  const code = await read(CODE);

  assert.match(xaml, /x:Name="AccountEmailText"/);
  assert.match(xaml, /x:Name="LogoutButton"[\s\S]*Click="LogoutButton_Click"/);
  assert.match(code, /await CloseAuthSensitiveStateAsync\(\);\n\s*var result = await _authService\.LogoutAsync\(\);/);
  assert.match(code, /AuthWall\.Visibility = Visibility\.Visible;\n\s*AuthFormPanel\.Visibility = Visibility\.Collapsed;\n\s*AuthCheckingPanel\.Visibility = Visibility\.Visible;/);
  assert.match(code, /OwnedWindows\.Cast<Window>\(\)\.ToArray\(\)/);
  assert.match(code, /_wirelessServer\.StopAsync\(\)/);
  assert.match(code, /_wifiCamera\.DisconnectAsync\(\)/);
  assert.match(code, /_localCamera\.DisconnectAsync\(\)/);
  assert.match(code, /_camera\.DisconnectAsync\(\)/);
});

test('windows auth UI: AI Bearer 仅随 HTTPS 请求发送，登录墙文案具备三语', async () => {
  const code = await read(CODE);
  const localization = await read(LOCALIZATION);

  assert.match(code, /Uri\.TryCreate\(endpoint, UriKind\.Absolute, out var aiEndpoint\)/);
  assert.match(code, /aiEndpoint\.Scheme\.Equals\([\s\S]*Uri\.UriSchemeHttps/);
  assert.match(code, /AuthenticationHeaderValue\([\s\S]*"Bearer", accountToken/);
  assert.match(localization, /\["登录"\] = new\("Sign In", "ログイン"\)/);
  assert.match(localization, /\["退出登录"\] = new\("Sign Out", "ログアウト"\)/);
});
