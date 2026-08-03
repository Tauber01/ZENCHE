package com.tauber.nikonlink;

import android.Manifest;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelUuid;

import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.Locale;
import java.util.UUID;

final class BluetoothRemoteController {
    static final UUID SERVICE_UUID = UUID.fromString(
            "7a5e0001-5e4e-4348-452d-52454d4f5445");
    static final UUID SHUTTER_UUID = UUID.fromString(
            "7a5e0002-5e4e-4348-452d-52454d4f5445");
    private static final UUID CLIENT_CONFIGURATION_UUID = UUID.fromString(
            "00002902-0000-1000-8000-00805f9b34fb");

    interface Listener {
        void onStatus(String status, boolean connected);
        void onShutter();
    }

    private final Context context;
    private final Listener listener;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final BluetoothAdapter adapter;
    private BluetoothGatt gatt;
    private boolean enabled;
    private boolean connected;

    BluetoothRemoteController(Context context, Listener listener) {
        this.context = context.getApplicationContext();
        this.listener = listener;
        BluetoothManager manager = (BluetoothManager) context.getSystemService(
                Context.BLUETOOTH_SERVICE);
        adapter = manager == null ? null : manager.getAdapter();
    }

    void start() {
        enabled = true;
        if (adapter == null) {
            status("此设备不支持蓝牙遥控", false);
            return;
        }
        if (!hasPermissions()) {
            status("等待蓝牙权限", false);
            return;
        }
        if (!adapter.isEnabled()) {
            status("请开启系统蓝牙", false);
            return;
        }
        scan();
    }

    void stop() {
        enabled = false;
        stopScan();
        if (gatt != null) {
            try {
                gatt.disconnect();
                gatt.close();
            } catch (SecurityException ignored) {
            }
        }
        gatt = null;
        connected = false;
        status("蓝牙遥控未开启", false);
    }

    boolean isConnected() {
        return connected;
    }

    private void scan() {
        BluetoothLeScanner scanner = adapter.getBluetoothLeScanner();
        if (scanner == null) {
            status("蓝牙扫描不可用", false);
            return;
        }
        status("正在搜索 ZENCHE 蓝牙遥控器…", false);
        try {
            scanner.startScan(
                    Collections.singletonList(
                            new ScanFilter.Builder()
                                    .setServiceUuid(new ParcelUuid(SERVICE_UUID))
                                    .build()),
                    new ScanSettings.Builder()
                            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                            .build(),
                    scanCallback);
        } catch (SecurityException error) {
            status("蓝牙权限不可用", false);
        }
    }

    private void stopScan() {
        if (adapter == null || !hasPermissions()) return;
        BluetoothLeScanner scanner = adapter.getBluetoothLeScanner();
        if (scanner == null) return;
        try {
            scanner.stopScan(scanCallback);
        } catch (SecurityException ignored) {
        }
    }

    private final ScanCallback scanCallback = new ScanCallback() {
        @Override
        public void onScanResult(int callbackType, ScanResult result) {
            if (!enabled || gatt != null) return;
            stopScan();
            String name;
            try {
                name = result.getDevice().getName();
            } catch (SecurityException ignored) {
                name = null;
            }
            status("正在连接 " + (name == null ? "ZENCHE Remote" : name) + "…", false);
            try {
                gatt = result.getDevice().connectGatt(
                        context,
                        false,
                        gattCallback,
                        BluetoothDevice.TRANSPORT_LE);
            } catch (SecurityException error) {
                status("蓝牙权限不可用", false);
            }
        }

        @Override
        public void onScanFailed(int errorCode) {
            status("蓝牙遥控扫描失败（" + errorCode + "）", false);
        }
    };

    private final BluetoothGattCallback gattCallback = new BluetoothGattCallback() {
        @Override
        public void onConnectionStateChange(
                BluetoothGatt current,
                int status,
                int newState) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                connected = true;
                status("蓝牙遥控已连接", true);
                try {
                    current.discoverServices();
                } catch (SecurityException error) {
                    status("蓝牙权限不可用", false);
                }
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                connected = false;
                try { current.close(); } catch (Exception ignored) { }
                if (gatt == current) gatt = null;
                status(enabled ? "蓝牙遥控已断开，正在重连…" : "蓝牙遥控未开启", false);
                if (enabled) main.postDelayed(BluetoothRemoteController.this::scan, 800);
            }
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt current, int statusCode) {
            BluetoothGattService service = current.getService(SERVICE_UUID);
            BluetoothGattCharacteristic characteristic = service == null
                    ? null
                    : service.getCharacteristic(SHUTTER_UUID);
            if (characteristic == null) {
                status("遥控器快门通道不可用", false);
                return;
            }
            try {
                current.setCharacteristicNotification(characteristic, true);
                BluetoothGattDescriptor descriptor = characteristic.getDescriptor(
                        CLIENT_CONFIGURATION_UUID);
                if (descriptor != null) {
                    if (Build.VERSION.SDK_INT >= 33) {
                        current.writeDescriptor(
                                descriptor,
                                BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
                    } else {
                        descriptor.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
                        current.writeDescriptor(descriptor);
                    }
                }
                status("蓝牙遥控已就绪", true);
            } catch (SecurityException error) {
                status("蓝牙权限不可用", false);
            }
        }

        @Override
        public void onCharacteristicChanged(
                BluetoothGatt current,
                BluetoothGattCharacteristic characteristic,
                byte[] value) {
            receive(characteristic, value);
        }

        @SuppressWarnings("deprecation")
        @Override
        public void onCharacteristicChanged(
                BluetoothGatt current,
                BluetoothGattCharacteristic characteristic) {
            receive(characteristic, characteristic.getValue());
        }
    };

    private void receive(BluetoothGattCharacteristic characteristic, byte[] value) {
        if (!SHUTTER_UUID.equals(characteristic.getUuid()) || !isShutter(value)) return;
        main.post(() -> {
            listener.onStatus("已收到蓝牙快门", true);
            listener.onShutter();
        });
    }

    private static boolean isShutter(byte[] value) {
        if (value == null || value.length == 0) return false;
        for (byte current : value) if (current != 0) return true;
        String text = new String(value, StandardCharsets.UTF_8)
                .trim().toLowerCase(Locale.ROOT);
        return "capture".equals(text) || "shutter".equals(text);
    }

    private boolean hasPermissions() {
        if (Build.VERSION.SDK_INT < 31) return true;
        return context.checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN)
                == PackageManager.PERMISSION_GRANTED
                && context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)
                == PackageManager.PERMISSION_GRANTED;
    }

    private void status(String value, boolean isConnected) {
        connected = isConnected;
        main.post(() -> listener.onStatus(value, isConnected));
    }
}
