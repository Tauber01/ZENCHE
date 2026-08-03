using Windows.Devices.Bluetooth;
using Windows.Devices.Bluetooth.Advertisement;
using Windows.Devices.Bluetooth.GenericAttributeProfile;
using Windows.Storage.Streams;

namespace NikonLink.Windows.Services;

public sealed class BluetoothRemoteController : IAsyncDisposable
{
    public static readonly Guid ServiceUuid =
        Guid.Parse("7A5E0001-5E4E-4348-452D-52454D4F5445");
    public static readonly Guid ShutterUuid =
        Guid.Parse("7A5E0002-5E4E-4348-452D-52454D4F5445");

    private BluetoothLEAdvertisementWatcher? _watcher;
    private BluetoothLEDevice? _device;
    private GattCharacteristic? _shutterCharacteristic;

    public bool Enabled { get; private set; }
    public bool Connected { get; private set; }
    public string Status { get; private set; } = "蓝牙遥控未开启";

    public event EventHandler? ShutterPressed;
    public event EventHandler<string>? StatusChanged;

    public void Start()
    {
        if (Enabled) return;
        Enabled = true;
        SetStatus("正在搜索 ZENCHE 蓝牙遥控器…");
        _watcher = new BluetoothLEAdvertisementWatcher
        {
            ScanningMode = BluetoothLEScanningMode.Active
        };
        _watcher.AdvertisementFilter.Advertisement.ServiceUuids.Add(ServiceUuid);
        _watcher.Received += Watcher_Received;
        _watcher.Stopped += Watcher_Stopped;
        _watcher.Start();
    }

    public void Stop()
    {
        Enabled = false;
        if (_watcher is not null)
        {
            _watcher.Received -= Watcher_Received;
            _watcher.Stopped -= Watcher_Stopped;
            if (_watcher.Status is BluetoothLEAdvertisementWatcherStatus.Started
                or BluetoothLEAdvertisementWatcherStatus.Created)
            {
                _watcher.Stop();
            }
            _watcher = null;
        }
        if (_shutterCharacteristic is not null)
        {
            _shutterCharacteristic.ValueChanged -= Shutter_ValueChanged;
            _shutterCharacteristic = null;
        }
        _device?.Dispose();
        _device = null;
        Connected = false;
        SetStatus("蓝牙遥控未开启");
    }

    public ValueTask DisposeAsync()
    {
        Stop();
        return ValueTask.CompletedTask;
    }

    private async void Watcher_Received(
        BluetoothLEAdvertisementWatcher sender,
        BluetoothLEAdvertisementReceivedEventArgs args)
    {
        if (!Enabled || _device is not null) return;
        sender.Stop();
        try
        {
            SetStatus("正在连接 ZENCHE Remote…");
            _device = await BluetoothLEDevice.FromBluetoothAddressAsync(
                args.BluetoothAddress);
            if (_device is null)
            {
                throw new InvalidOperationException("无法打开蓝牙遥控器");
            }
            _device.ConnectionStatusChanged += Device_ConnectionStatusChanged;
            var services = await _device.GetGattServicesForUuidAsync(
                ServiceUuid,
                BluetoothCacheMode.Uncached);
            if (services.Status != GattCommunicationStatus.Success ||
                services.Services.Count == 0)
            {
                throw new InvalidOperationException("遥控器服务不可用");
            }
            var characteristics = await services.Services[0]
                .GetCharacteristicsForUuidAsync(
                    ShutterUuid,
                    BluetoothCacheMode.Uncached);
            if (characteristics.Status != GattCommunicationStatus.Success ||
                characteristics.Characteristics.Count == 0)
            {
                throw new InvalidOperationException("遥控器快门通道不可用");
            }
            _shutterCharacteristic = characteristics.Characteristics[0];
            _shutterCharacteristic.ValueChanged += Shutter_ValueChanged;
            var result = await _shutterCharacteristic
                .WriteClientCharacteristicConfigurationDescriptorAsync(
                    GattClientCharacteristicConfigurationDescriptorValue.Notify);
            if (result != GattCommunicationStatus.Success)
            {
                throw new InvalidOperationException("无法订阅蓝牙快门通知");
            }
            Connected = true;
            SetStatus($"蓝牙遥控已就绪 · {_device.Name}");
        }
        catch (Exception error)
        {
            Connected = false;
            SetStatus($"蓝牙遥控连接失败：{error.Message}");
            RestartScan();
        }
    }

    private void Shutter_ValueChanged(
        GattCharacteristic sender,
        GattValueChangedEventArgs args)
    {
        using var reader = DataReader.FromBuffer(args.CharacteristicValue);
        var bytes = new byte[reader.UnconsumedBufferLength];
        reader.ReadBytes(bytes);
        if (bytes.Length == 0 || bytes.All(value => value == 0)) return;
        SetStatus("已收到蓝牙快门");
        ShutterPressed?.Invoke(this, EventArgs.Empty);
    }

    private void Device_ConnectionStatusChanged(
        BluetoothLEDevice sender,
        object args)
    {
        Connected = sender.ConnectionStatus == BluetoothConnectionStatus.Connected;
        if (!Connected && Enabled)
        {
            SetStatus("蓝牙遥控已断开，正在重连…");
            RestartScan();
        }
    }

    private void Watcher_Stopped(
        BluetoothLEAdvertisementWatcher sender,
        BluetoothLEAdvertisementWatcherStoppedEventArgs args)
    {
        if (Enabled && _device is null)
        {
            RestartScan();
        }
    }

    private async void RestartScan()
    {
        if (!Enabled) return;
        if (_shutterCharacteristic is not null)
        {
            _shutterCharacteristic.ValueChanged -= Shutter_ValueChanged;
            _shutterCharacteristic = null;
        }
        if (_device is not null)
        {
            _device.ConnectionStatusChanged -= Device_ConnectionStatusChanged;
            _device.Dispose();
            _device = null;
        }
        await Task.Delay(800);
        if (!Enabled) return;
        try
        {
            _watcher?.Start();
        }
        catch (Exception error)
        {
            SetStatus($"蓝牙遥控不可用：{error.Message}");
        }
    }

    private void SetStatus(string value)
    {
        Status = value;
        StatusChanged?.Invoke(this, value);
    }
}
