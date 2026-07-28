package com.tauber.nikonlink;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.Color;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbManager;
import android.os.Build;
import android.os.Bundle;
import android.util.Base64;
import android.view.Window;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;

import org.json.JSONObject;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

public final class MainActivity extends Activity {
    private static final String USB_PERMISSION_ACTION = "com.tauber.nikonlink.USB_PERMISSION";

    private final ExecutorService cameraExecutor = Executors.newSingleThreadExecutor();
    private WebView webView;
    private PtpCamera camera;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        Window window = getWindow();
        window.setStatusBarColor(Color.rgb(245, 247, 251));
        window.setNavigationBarColor(Color.rgb(17, 19, 24));
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            window.getDecorView().setSystemUiVisibility(android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);
        }

        camera = new PtpCamera(this);
        webView = new WebView(this);
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setMediaPlaybackRequiresUserGesture(false);
        settings.setBuiltInZoomControls(false);
        settings.setDisplayZoomControls(false);
        webView.setWebChromeClient(new WebChromeClient());
        webView.setBackgroundColor(Color.TRANSPARENT);
        webView.addJavascriptInterface(new CameraBridge(), "NikonAndroid");
        setContentView(webView);
        webView.loadUrl("file:///android_asset/web/index.html");
    }

    boolean ensureUsbPermission(UsbManager manager, UsbDevice device) throws InterruptedException {
        if (manager.hasPermission(device)) return true;
        CountDownLatch latch = new CountDownLatch(1);
        AtomicBoolean granted = new AtomicBoolean(false);
        BroadcastReceiver receiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                if (USB_PERMISSION_ACTION.equals(intent.getAction())) {
                    UsbDevice returned = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);
                    if (returned != null && returned.getDeviceId() == device.getDeviceId()) {
                        granted.set(intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false));
                        latch.countDown();
                    }
                }
            }
        };

        runOnUiThread(() -> {
            IntentFilter filter = new IntentFilter(USB_PERMISSION_ACTION);
            if (Build.VERSION.SDK_INT >= 33) registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
            else registerReceiver(receiver, filter);
            PendingIntent permissionIntent = PendingIntent.getBroadcast(
                    this,
                    device.getDeviceId(),
                    new Intent(USB_PERMISSION_ACTION).setPackage(getPackageName()),
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_MUTABLE);
            manager.requestPermission(device, permissionIntent);
        });

        boolean finished = latch.await(35, TimeUnit.SECONDS);
        runOnUiThread(() -> {
            try {
                unregisterReceiver(receiver);
            } catch (IllegalArgumentException ignored) {
            }
        });
        return finished && granted.get();
    }

    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) webView.goBack();
        else super.onBackPressed();
    }

    @Override
    protected void onDestroy() {
        cameraExecutor.submit(camera::disconnect);
        cameraExecutor.shutdown();
        webView.destroy();
        super.onDestroy();
    }

    private final class CameraBridge {
        @JavascriptInterface
        public void postMessage(String json) {
            cameraExecutor.submit(() -> {
                String id = "";
                try {
                    JSONObject request = new JSONObject(json);
                    id = request.getString("id");
                    String method = request.getString("method");
                    JSONObject params = request.optJSONObject("params");
                    Map<String, Object> result;
                    switch (method) {
                        case "connect":
                            result = camera.connect();
                            break;
                        case "startLiveView":
                            camera.startLiveView();
                            result = new HashMap<>();
                            break;
                        case "stopLiveView":
                            camera.stopLiveView();
                            result = new HashMap<>();
                            break;
                        case "getLiveViewFrame":
                            result = imageResult(camera.getLiveViewFrame(), false);
                            break;
                        case "capture":
                            result = imageResult(camera.capture(), true);
                            break;
                        case "setParameter":
                            if (params == null) throw new Exception("参数格式无效。");
                            String name = params.getString("name");
                            Object value = params.get("value");
                            Object applied = camera.setParameter(name, value);
                            result = PtpCamera.mapOf("value", applied);
                            break;
                        case "disconnect":
                            camera.disconnect();
                            result = new HashMap<>();
                            break;
                        default:
                            throw new Exception("未知操作：" + method);
                    }
                    respond(id, success(result));
                } catch (Exception error) {
                    respond(id, failure(error.getMessage() == null ? "原生相机操作失败。" : error.getMessage()));
                }
            });
        }
    }

    private static Map<String, Object> imageResult(byte[] jpeg, boolean capture) {
        return PtpCamera.mapOf(
                "dataUrl", "data:image/jpeg;base64," + Base64.encodeToString(jpeg, Base64.NO_WRAP),
                "width", 1024,
                "height", 680,
                "name", capture ? "NIKON_Z8_CAPTURE.JPG" : "NIKON_Z8_PREVIEW.JPG");
    }

    private static JSONObject success(Map<String, Object> result) throws Exception {
        JSONObject response = new JSONObject();
        response.put("ok", true);
        response.put("result", new JSONObject(result));
        return response;
    }

    private static JSONObject failure(String message) {
        JSONObject response = new JSONObject();
        try {
            response.put("ok", false);
            response.put("code", "NATIVE_ERROR");
            response.put("error", message);
        } catch (Exception ignored) {
        }
        return response;
    }

    private void respond(String id, JSONObject response) {
        if (id == null || id.isEmpty()) return;
        String script = "window.NikonNativeBridge._resolve(" + JSONObject.quote(id) + "," + response + ");";
        runOnUiThread(() -> webView.evaluateJavascript(script, null));
    }
}
