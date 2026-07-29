package com.tauber.nikonlink;

import java.io.File;

final class WirelessTransferServer {
    static final int FTP_PORT = WirelessFtpServer.PORT;
    static final int HTTP_PORT = WirelessHttpServer.PORT;
    static final String USERNAME = WirelessFtpServer.USERNAME;
    static final String PASSWORD = WirelessFtpServer.PASSWORD;

    interface Listener {
        void onStatus(String status);
        void onFileReceived(File file);
        void onError(String message);
    }

    private final WirelessFtpServer ftp;
    private final WirelessHttpServer http;
    private final Listener listener;
    private volatile boolean running;

    WirelessTransferServer(File directory, Listener listener) {
        this.listener = listener;
        ftp = new WirelessFtpServer(
                directory,
                new WirelessFtpServer.Listener() {
                    @Override
                    public void onStatus(String status) {
                        publishProtocolStatus(status);
                    }

                    @Override
                    public void onFileReceived(File file) {
                        WirelessTransferServer.this.listener.onFileReceived(file);
                    }

                    @Override
                    public void onError(String message) {
                        fail("FTP 启动失败：" + message);
                    }
                });
        http = new WirelessHttpServer(
                directory,
                new WirelessHttpServer.Listener() {
                    @Override
                    public void onStatus(String status) {
                        publishProtocolStatus(status);
                    }

                    @Override
                    public void onFileReceived(File file) {
                        WirelessTransferServer.this.listener.onFileReceived(file);
                    }

                    @Override
                    public void onError(String message) {
                        fail("HTTP / WebDAV 启动失败：" + message);
                    }
                });
    }

    synchronized void start() {
        if (running) return;
        running = true;
        ftp.start();
        http.start();
        listener.onStatus("等待 FTP / HTTP / WebDAV 图片");
    }

    synchronized void stop() {
        if (!running) return;
        running = false;
        ftp.stop();
        http.stop();
        listener.onStatus("无线收件箱未开启");
    }

    boolean isRunning() {
        return running;
    }

    String getLocalAddress() {
        return ftp.getLocalAddress();
    }

    private void publishProtocolStatus(String status) {
        if (!running || status.equals("无线收件箱未开启")) return;
        if (status.equals("等待相机无线传输")) {
            listener.onStatus("等待 FTP / HTTP / WebDAV 图片");
        } else {
            listener.onStatus(status);
        }
    }

    private void fail(String message) {
        synchronized (this) {
            if (!running) return;
            running = false;
        }
        ftp.stop();
        http.stop();
        listener.onError(message);
    }
}
