#include "CRSDK/CameraRemote_SDK.h"
#include "CRSDK/IDeviceCallback.h"

#include <algorithm>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>

namespace {

int writeText(const std::string& value, char* output, std::size_t capacity) {
    if (output == nullptr || capacity == 0) return -1;
    const std::size_t count = std::min(value.size(), capacity - 1);
    std::memcpy(output, value.data(), count);
    output[count] = '\0';
    return count == value.size() ? 0 : -2;
}

std::string jsonEscape(const char* text) {
    if (text == nullptr) return {};
    std::ostringstream result;
    for (const unsigned char* value =
             reinterpret_cast<const unsigned char*>(text);
         *value != 0;
         ++value) {
        switch (*value) {
            case '"': result << "\\\""; break;
            case '\\': result << "\\\\"; break;
            case '\n': result << "\\n"; break;
            case '\r': result << "\\r"; break;
            case '\t': result << "\\t"; break;
            default:
                if (*value >= 0x20) result << static_cast<char>(*value);
                break;
        }
    }
    return result.str();
}

class SonyCallback final : public SCRSDK::IDeviceCallback {
public:
    void OnConnected(SCRSDK::DeviceConnectionVersioin) override {
        std::lock_guard<std::mutex> lock(mutex);
        connected = true;
        connectionEvent = true;
        condition.notify_all();
    }

    void OnDisconnected(CrInt32u error) override {
        std::lock_guard<std::mutex> lock(mutex);
        connected = false;
        disconnected = true;
        lastError = error;
        condition.notify_all();
    }

    void OnCompleteDownload(CrChar* filename, CrInt32u) override {
        std::lock_guard<std::mutex> lock(mutex);
        downloadedFile = filename == nullptr ? "" : filename;
        downloadEvent = true;
        condition.notify_all();
    }

    void OnError(CrInt32u error) override {
        std::lock_guard<std::mutex> lock(mutex);
        lastError = error;
        condition.notify_all();
    }

    void resetConnection() {
        std::lock_guard<std::mutex> lock(mutex);
        connectionEvent = false;
        disconnected = false;
        lastError = 0;
    }

    bool waitForConnection(std::chrono::milliseconds timeout) {
        std::unique_lock<std::mutex> lock(mutex);
        condition.wait_for(lock, timeout, [&] {
            return connectionEvent || disconnected || lastError != 0;
        });
        return connected;
    }

    void resetDownload() {
        std::lock_guard<std::mutex> lock(mutex);
        downloadedFile.clear();
        downloadEvent = false;
        lastError = 0;
    }

    bool waitForDownload(
        std::chrono::milliseconds timeout,
        std::string& filename,
        CrInt32u& error) {
        std::unique_lock<std::mutex> lock(mutex);
        condition.wait_for(lock, timeout, [&] {
            return downloadEvent || lastError != 0 || !connected;
        });
        filename = downloadedFile;
        error = lastError;
        return downloadEvent && !filename.empty();
    }

    std::mutex mutex;
    std::condition_variable condition;
    bool connected = false;
    bool connectionEvent = false;
    bool disconnected = false;
    bool downloadEvent = false;
    CrInt32u lastError = 0;
    std::string downloadedFile;
};

class SonyCameraSession {
public:
    int probe(char* output, std::size_t capacity) {
        std::lock_guard<std::mutex> sessionLock(sessionMutex);
        if (handle != 0) {
            std::ostringstream json;
            json << "{\"loaded\":true,\"initialized\":true,"
                 << "\"version\":" << SCRSDK::GetSDKVersion() << ','
                 << "\"devices\":[{\"model\":\""
                 << jsonEscape(model.c_str())
                 << "\",\"connected\":true}]}";
            return writeText(json.str(), output, capacity);
        }

        if (!SCRSDK::Init()) {
            return writeText(
                "{\"loaded\":true,\"initialized\":false,"
                "\"version\":0,\"devices\":[]}",
                output,
                capacity);
        }
        SCRSDK::ICrEnumCameraObjectInfo* cameras = nullptr;
        const SCRSDK::CrError error = SCRSDK::EnumCameraObjects(&cameras, 3);
        std::ostringstream json;
        json << "{\"loaded\":true,\"initialized\":true,"
             << "\"version\":" << SCRSDK::GetSDKVersion()
             << ",\"errorCode\":" << error << ",\"devices\":[";
        if (error == SCRSDK::CrError_None && cameras != nullptr) {
            const CrInt32u count = cameras->GetCount();
            for (CrInt32u index = 0; index < count; ++index) {
                const auto* camera = cameras->GetCameraObjectInfo(index);
                if (camera == nullptr) continue;
                if (index != 0) json << ',';
                json << "{\"model\":\""
                     << jsonEscape(camera->GetModel())
                     << "\",\"name\":\""
                     << jsonEscape(camera->GetName())
                     << "\",\"connected\":false}";
            }
        }
        if (cameras != nullptr) cameras->Release();
        json << "]}";
        SCRSDK::Release();
        return writeText(json.str(), output, capacity);
    }

    int connect(
        const char* saveDirectory,
        char* modelOutput,
        std::size_t modelCapacity) {
        std::lock_guard<std::mutex> sessionLock(sessionMutex);
        if (handle != 0) return writeText(model, modelOutput, modelCapacity);
        if (!SCRSDK::Init()) return -100;

        SCRSDK::ICrEnumCameraObjectInfo* discovered = nullptr;
        SCRSDK::CrError error = SCRSDK::EnumCameraObjects(&discovered, 3);
        if (error != SCRSDK::CrError_None || discovered == nullptr ||
            discovered->GetCount() == 0) {
            if (discovered != nullptr) discovered->Release();
            SCRSDK::Release();
            return error == SCRSDK::CrError_None
                ? -101
                : static_cast<int>(error);
        }
        const auto* info = discovered->GetCameraObjectInfo(0);
        if (info == nullptr) {
            discovered->Release();
            SCRSDK::Release();
            return -102;
        }

        callback.resetConnection();
        CrInt64 newHandle = 0;
        error = SCRSDK::Connect(
            const_cast<SCRSDK::ICrCameraObjectInfo*>(info),
            &callback,
            &newHandle,
            SCRSDK::CrSdkControlMode_Remote,
            SCRSDK::CrReconnecting_ON);
        if (error != SCRSDK::CrError_None || newHandle == 0 ||
            !callback.waitForConnection(std::chrono::seconds(8))) {
            if (newHandle != 0) SCRSDK::ReleaseDevice(newHandle);
            discovered->Release();
            SCRSDK::Release();
            return error == SCRSDK::CrError_None
                ? -103
                : static_cast<int>(error);
        }

        handle = newHandle;
        cameraList = discovered;
        model = info->GetModel() == nullptr ? "Sony Camera" : info->GetModel();
        saveRoot = saveDirectory == nullptr ? "/tmp" : saveDirectory;
        std::filesystem::create_directories(saveRoot);
        std::string prefix = "ZENCHE";
        error = SCRSDK::SetSaveInfo(
            handle,
            saveRoot.data(),
            prefix.data(),
            -1);
        if (error != SCRSDK::CrError_None) {
            disconnectLocked();
            return static_cast<int>(error);
        }
        return writeText(model, modelOutput, modelCapacity);
    }

    int disconnect() {
        std::lock_guard<std::mutex> sessionLock(sessionMutex);
        return disconnectLocked();
    }

    int liveView(
        std::uint8_t* output,
        std::size_t capacity,
        std::size_t* actualSize) {
        std::lock_guard<std::mutex> sessionLock(sessionMutex);
        if (actualSize == nullptr || handle == 0) return -110;
        SCRSDK::CrImageInfo info;
        SCRSDK::CrError error = SCRSDK::GetLiveViewImageInfo(handle, &info);
        if (error != SCRSDK::CrError_None) return static_cast<int>(error);
        const std::size_t required = info.GetBufferSize();
        *actualSize = required;
        if (output == nullptr || capacity < required) return -111;
        SCRSDK::CrImageDataBlock image;
        image.SetData(output);
        image.SetSize(static_cast<CrInt32u>(capacity));
        error = SCRSDK::GetLiveViewImage(handle, &image);
        if (error != SCRSDK::CrError_None) return static_cast<int>(error);
        *actualSize = image.GetImageSize();
        return *actualSize == 0 ? -112 : 0;
    }

    int capture(char* output, std::size_t capacity) {
        std::unique_lock<std::mutex> sessionLock(sessionMutex);
        if (handle == 0) return -120;
        callback.resetDownload();
        SCRSDK::CrError error = SCRSDK::SendCommand(
            handle,
            SCRSDK::CrCommandId_Release,
            SCRSDK::CrCommandParam_Down);
        if (error != SCRSDK::CrError_None) return static_cast<int>(error);
        std::this_thread::sleep_for(std::chrono::milliseconds(35));
        error = SCRSDK::SendCommand(
            handle,
            SCRSDK::CrCommandId_Release,
            SCRSDK::CrCommandParam_Up);
        if (error != SCRSDK::CrError_None) return static_cast<int>(error);
        sessionLock.unlock();
        std::string filename;
        CrInt32u callbackError = 0;
        if (!callback.waitForDownload(
                std::chrono::seconds(60),
                filename,
                callbackError)) {
            return callbackError == 0 ? -121 : static_cast<int>(callbackError);
        }
        std::filesystem::path result(filename);
        if (!result.is_absolute()) result = std::filesystem::path(saveRoot) / result;
        return writeText(result.string(), output, capacity);
    }

    int setMovieRecording(bool recording) {
        std::lock_guard<std::mutex> sessionLock(sessionMutex);
        if (handle == 0) return -130;
        const SCRSDK::CrError error = SCRSDK::SendCommand(
            handle,
            SCRSDK::CrCommandId_MovieRecord,
            recording
                ? SCRSDK::CrCommandParam_Down
                : SCRSDK::CrCommandParam_Up);
        return static_cast<int>(error);
    }

    int autofocus(bool pressed) {
        std::lock_guard<std::mutex> sessionLock(sessionMutex);
        if (handle == 0) return -140;
        const SCRSDK::CrError error = SCRSDK::SendCommand(
            handle,
            SCRSDK::CrCommandId_TrackingOnAndAFOn,
            pressed
                ? SCRSDK::CrCommandParam_Down
                : SCRSDK::CrCommandParam_Up);
        return static_cast<int>(error);
    }

    int setProperty(CrInt32u code, CrInt64u value) {
        std::lock_guard<std::mutex> sessionLock(sessionMutex);
        if (handle == 0) return -150;
        SCRSDK::CrDeviceProperty* properties = nullptr;
        CrInt32 count = 0;
        SCRSDK::CrError error = SCRSDK::GetSelectDeviceProperties(
            handle,
            1,
            &code,
            &properties,
            &count);
        if (error != SCRSDK::CrError_None) return static_cast<int>(error);
        if (properties == nullptr || count < 1 ||
            !properties[0].IsSetEnableCurrentValue()) {
            if (properties != nullptr) {
                SCRSDK::ReleaseDeviceProperties(handle, properties);
            }
            return -151;
        }
        SCRSDK::CrDeviceProperty writable(properties[0]);
        SCRSDK::ReleaseDeviceProperties(handle, properties);
        writable.SetCurrentValue(value);
        error = SCRSDK::SetDeviceProperty(handle, &writable);
        return static_cast<int>(error);
    }

private:
    int disconnectLocked() {
        if (handle != 0) {
            SCRSDK::Disconnect(handle);
            SCRSDK::ReleaseDevice(handle);
        }
        handle = 0;
        if (cameraList != nullptr) cameraList->Release();
        cameraList = nullptr;
        model.clear();
        saveRoot.clear();
        SCRSDK::Release();
        return 0;
    }

    std::mutex sessionMutex;
    SonyCallback callback;
    CrInt64 handle = 0;
    SCRSDK::ICrEnumCameraObjectInfo* cameraList = nullptr;
    std::string model;
    std::string saveRoot;
};

SonyCameraSession& session() {
    static SonyCameraSession value;
    return value;
}

}  // namespace

extern "C" int ZencheProbeSonyCameraRemoteSDK(
    char* output,
    std::size_t capacity) {
    return session().probe(output, capacity);
}

extern "C" int ZencheSonySDKConnect(
    const char* saveDirectory,
    char* modelOutput,
    std::size_t modelCapacity) {
    return session().connect(saveDirectory, modelOutput, modelCapacity);
}

extern "C" int ZencheSonySDKDisconnect() {
    return session().disconnect();
}

extern "C" int ZencheSonySDKGetLiveViewImage(
    std::uint8_t* output,
    std::size_t capacity,
    std::size_t* actualSize) {
    return session().liveView(output, capacity, actualSize);
}

extern "C" int ZencheSonySDKCapture(char* output, std::size_t capacity) {
    return session().capture(output, capacity);
}

extern "C" int ZencheSonySDKSetMovieRecording(bool recording) {
    return session().setMovieRecording(recording);
}

extern "C" int ZencheSonySDKAutofocus(bool pressed) {
    return session().autofocus(pressed);
}

extern "C" int ZencheSonySDKSetProperty(
    std::uint32_t code,
    std::uint64_t value) {
    return session().setProperty(code, value);
}
