package com.tauber.nikonlink;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Bundle;

final class LocationTaggingController implements LocationListener {
    static final class Snapshot {
        final double latitude;
        final double longitude;
        final double altitude;
        final double accuracy;
        final long timestamp;

        Snapshot(Location location) {
            latitude = location.getLatitude();
            longitude = location.getLongitude();
            altitude = location.hasAltitude() ? location.getAltitude() : 0;
            accuracy = location.hasAccuracy() ? location.getAccuracy() : 0;
            timestamp = location.getTime();
        }
    }

    interface Listener {
        void onStatus(String status);
    }

    private final Context context;
    private final LocationManager manager;
    private final Listener listener;
    private boolean enabled;
    private Snapshot latest;

    LocationTaggingController(Context context, Listener listener) {
        this.context = context.getApplicationContext();
        this.listener = listener;
        manager = (LocationManager) context.getSystemService(Context.LOCATION_SERVICE);
    }

    void start() {
        enabled = true;
        refresh();
    }

    void refresh() {
        if (!enabled) return;
        if (!hasPermission()) {
            listener.onStatus("等待定位授权");
            return;
        }
        if (manager == null) {
            listener.onStatus("此设备不支持定位");
            return;
        }
        listener.onStatus("正在获取位置…");
        request(LocationManager.NETWORK_PROVIDER);
        request(LocationManager.GPS_PROVIDER);
    }

    void stop() {
        enabled = false;
        latest = null;
        if (manager != null) {
            try { manager.removeUpdates(this); } catch (SecurityException ignored) { }
        }
        listener.onStatus("定位未开启");
    }

    Snapshot snapshot() {
        if (!enabled || latest == null
                || System.currentTimeMillis() - latest.timestamp > 120_000) {
            return null;
        }
        return latest;
    }

    private void request(String provider) {
        try {
            if (!manager.isProviderEnabled(provider)) return;
            Location last = manager.getLastKnownLocation(provider);
            if (last != null) update(last);
            manager.requestSingleUpdate(provider, this, null);
        } catch (SecurityException | IllegalArgumentException ignored) {
        }
    }

    private boolean hasPermission() {
        return context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                == PackageManager.PERMISSION_GRANTED
                || context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
                == PackageManager.PERMISSION_GRANTED;
    }

    private void update(Location location) {
        if (location == null || location.getAccuracy() < 0) return;
        latest = new Snapshot(location);
        if (manager != null) {
            try { manager.removeUpdates(this); } catch (SecurityException ignored) { }
        }
        listener.onStatus(String.format("定位就绪 · ±%.0f m", location.getAccuracy()));
    }

    @Override
    public void onLocationChanged(Location location) {
        update(location);
    }

    @Override public void onStatusChanged(String provider, int status, Bundle extras) { }
    @Override public void onProviderEnabled(String provider) { }
    @Override public void onProviderDisabled(String provider) { }
}
