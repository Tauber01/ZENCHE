#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <sys/sysctl.h>
#include <unistd.h>

#include <cstdint>
#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <sstream>
#include <string>
#include <vector>

namespace {

using NKERROR = std::int32_t;
using ULONG = std::uint32_t;
using NKREF = void*;
using NKPARAM = std::uintptr_t;

struct NikonCallbacks {
    void* uiRequest;
    void* event;
    void* progress;
    void* data;
    void* liveViewData;
    NKREF reference;
};

struct NikonDeviceInfo {
    ULONG id;
    char name[64];
    bool available;
    ULONG connectedPid;
    char version[64];
};

struct NikonDeviceList {
    ULONG elements;
    ULONG value;
    NikonDeviceInfo* devices;
};

using AllocateMemory = void* (*)(std::size_t);
using FreeMemory = void (*)(void*);
using InitializeSDK = NKERROR (*)(
    AllocateMemory,
    FreeMemory,
    NikonCallbacks*,
    NikonDeviceList**,
    void**);
using FreeSDK = std::int32_t (*)();
using CompletionProc = void (*)(NKREF, NKERROR);
using EnumDevices = NKERROR (*)(
    NikonDeviceList**,
    CompletionProc,
    NKREF);

void* sdkAllocate(std::size_t size) { return std::malloc(size); }
void sdkFree(void* memory) { std::free(memory); }
std::uint32_t uiRequest(NKREF, void*) { return 0; }
void eventCallback(NKREF, ULONG, NKPARAM) {}
void progressCallback(ULONG, ULONG, NKREF, ULONG, ULONG) {}
NKERROR dataCallback(NKREF, void*, void*) { return 0; }
void liveViewCallback(NKREF, void*) {}

void freeDeviceList(NikonDeviceList*& list) {
    if (list == nullptr) return;
    std::free(list->devices);
    std::free(list);
    list = nullptr;
}

std::string executableDirectory() {
    std::uint32_t length = 0;
    _NSGetExecutablePath(nullptr, &length);
    std::vector<char> path(length + 1, 0);
    if (_NSGetExecutablePath(path.data(), &length) != 0) return {};
    return std::filesystem::path(path.data()).parent_path().string();
}

std::string jsonEscape(const char* source, std::size_t maximumLength) {
    std::ostringstream result;
    if (source == nullptr) return {};
    for (std::size_t index = 0;
         index < maximumLength && source[index] != '\0';
         ++index) {
        const unsigned char value = static_cast<unsigned char>(source[index]);
        switch (value) {
            case '"': result << "\\\""; break;
            case '\\': result << "\\\\"; break;
            case '\b': result << "\\b"; break;
            case '\f': result << "\\f"; break;
            case '\n': result << "\\n"; break;
            case '\r': result << "\\r"; break;
            case '\t': result << "\\t"; break;
            default:
                if (value >= 0x20) result << static_cast<char>(value);
                break;
        }
    }
    return result.str();
}

int writeResult(const std::string& value, char* output, std::size_t capacity) {
    if (output == nullptr || capacity == 0) return -1;
    const std::size_t count = std::min(value.size(), capacity - 1);
    std::memcpy(output, value.data(), count);
    output[count] = '\0';
    return count == value.size() ? 0 : -2;
}

std::string lastDynamicLoaderError() {
    const char* message = dlerror();
    return jsonEscape(message == nullptr ? "unknown loader error" : message, 4096);
}

struct NikonImageLibraryParam {
    unsigned long size;
    unsigned long version;
    unsigned long virtualMemoryMegabytes;
    void** library;
    unsigned char virtualMemoryFile[1024];
};

using NikonImageEntry = unsigned long (*)(unsigned long, void*);

}  // namespace

extern "C" int ZencheProbeNikonRemoteSDK(char* output, std::size_t capacity) {
    const std::string modulePath = executableDirectory() +
        "/TypeCommon Module.bundle";
    CFStringRef path = CFStringCreateWithCString(
        kCFAllocatorDefault,
        modulePath.c_str(),
        kCFStringEncodingUTF8);
    if (path == nullptr) {
        return writeResult(
            "{\"loaded\":false,\"initialized\":false,\"errorCode\":-1,"
            "\"message\":\"invalid module path\",\"devices\":[]}",
            output,
            capacity);
    }
    CFURLRef url = CFURLCreateWithFileSystemPath(
        kCFAllocatorDefault,
        path,
        kCFURLPOSIXPathStyle,
        true);
    CFRelease(path);
    CFBundleRef bundle = url == nullptr
        ? nullptr
        : CFBundleCreate(kCFAllocatorDefault, url);
    if (url != nullptr) CFRelease(url);
    if (bundle == nullptr || !CFBundleLoadExecutable(bundle)) {
        if (bundle != nullptr) CFRelease(bundle);
        return writeResult(
            "{\"loaded\":false,\"initialized\":false,\"errorCode\":-2,"
            "\"message\":\"TypeCommon Module.bundle could not be loaded\","
            "\"devices\":[]}",
            output,
            capacity);
    }

    auto initialize = reinterpret_cast<InitializeSDK>(
        CFBundleGetFunctionPointerForName(bundle, CFSTR("InitializeSDK")));
    auto freeSdk = reinterpret_cast<FreeSDK>(
        CFBundleGetFunctionPointerForName(bundle, CFSTR("FreeSDK")));
    auto enumDevices = reinterpret_cast<EnumDevices>(
        CFBundleGetFunctionPointerForName(bundle, CFSTR("EnumDevices")));
    if (initialize == nullptr || freeSdk == nullptr || enumDevices == nullptr) {
        CFBundleUnloadExecutable(bundle);
        CFRelease(bundle);
        return writeResult(
            "{\"loaded\":true,\"initialized\":false,\"errorCode\":-3,"
            "\"message\":\"required Remote SDK entry points are missing\","
            "\"devices\":[]}",
            output,
            capacity);
    }

    NikonCallbacks callbacks{};
    callbacks.uiRequest = reinterpret_cast<void*>(uiRequest);
    callbacks.event = reinterpret_cast<void*>(eventCallback);
    callbacks.progress = reinterpret_cast<void*>(progressCallback);
    callbacks.data = reinterpret_cast<void*>(dataCallback);
    callbacks.liveViewData = reinterpret_cast<void*>(liveViewCallback);
    NikonDeviceList* list = nullptr;
    const NKERROR result = initialize(
        sdkAllocate,
        sdkFree,
        &callbacks,
        &list,
        nullptr);

    // The macOS SDK discovers USB cameras asynchronously through the main
    // Core Foundation run loop. InitializeSDK can therefore succeed with an
    // empty initial list. Give discovery time to settle and refresh the list
    // through the SDK's documented EnumDevices entry point.
    if (result == 0 && (list == nullptr || list->elements == 0)) {
        for (int attempt = 0; attempt < 60; ++attempt) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, false);
            if (attempt % 5 != 4) continue;
            NikonDeviceList* refreshed = nullptr;
            const NKERROR enumResult = enumDevices(
                &refreshed,
                nullptr,
                nullptr);
            if (enumResult == 0 && refreshed != nullptr) {
                if (refreshed != list) {
                    freeDeviceList(list);
                    list = refreshed;
                }
            } else {
                freeDeviceList(refreshed);
            }
            if (list != nullptr && list->elements > 0) break;
        }
    }

    std::ostringstream json;
    json << "{\"loaded\":true,\"initialized\":"
         << (result == 0 ? "true" : "false")
         << ",\"errorCode\":" << result
         << ",\"message\":\""
         << (result == 0 ? "Remote SDK 2.0.0 ready" : "InitializeSDK failed")
         << "\",\"devices\":[";
    if (result == 0 && list != nullptr && list->devices != nullptr) {
        const ULONG count = std::min<ULONG>(list->elements, 64);
        for (ULONG index = 0; index < count; ++index) {
            if (index != 0) json << ',';
            const NikonDeviceInfo& device = list->devices[index];
            json << "{\"id\":" << device.id
                 << ",\"name\":\"" << jsonEscape(device.name, 64)
                 << "\",\"available\":"
                 << (device.available ? "true" : "false")
                 << ",\"version\":\""
                 << jsonEscape(device.version, 64) << "\"}";
        }
    }
    json << "]}";

    if (result == 0) freeSdk();
    freeDeviceList(list);
    CFBundleUnloadExecutable(bundle);
    CFRelease(bundle);
    return writeResult(json.str(), output, capacity);
}

extern "C" int ZencheProbeNikonImageSDK(char* output, std::size_t capacity) {
    const std::string libraryPath = executableDirectory() +
        "/../Frameworks/libImgSDK.dylib";
    dlerror();
    void* library = dlopen(libraryPath.c_str(), RTLD_NOW | RTLD_LOCAL);
    if (library == nullptr) {
        std::ostringstream json;
        json << "{\"loaded\":false,\"initialized\":false,\"errorCode\":-1,"
             << "\"message\":\"" << lastDynamicLoaderError() << "\"}";
        return writeResult(json.str(), output, capacity);
    }
    dlerror();
    auto entry = reinterpret_cast<NikonImageEntry>(dlsym(library, "Nkfl_Entry"));
    if (entry == nullptr) {
        const std::string message = lastDynamicLoaderError();
        dlclose(library);
        return writeResult(
            "{\"loaded\":true,\"initialized\":false,\"errorCode\":-2,"
            "\"message\":\"" + message + "\"}",
            output,
            capacity);
    }

    NikonImageLibraryParam parameters{};
    void* sdkLibrary = nullptr;
    parameters.size = sizeof(parameters);
    parameters.version = 0x01000000;
    parameters.virtualMemoryMegabytes = 512;
    parameters.library = &sdkLibrary;
    const std::string swapPath = "/tmp/zenche-image-sdk-" +
        std::to_string(getpid()) + ".tmp";
    std::strncpy(
        reinterpret_cast<char*>(parameters.virtualMemoryFile),
        swapPath.c_str(),
        sizeof(parameters.virtualMemoryFile) - 1);
    const unsigned long result = entry(0x0001, &parameters);
    if (result == 0) entry(0x0002, nullptr);
    unlink(swapPath.c_str());
    dlclose(library);

    std::ostringstream json;
    json << "{\"loaded\":true,\"initialized\":"
         << (result == 0 ? "true" : "false")
         << ",\"errorCode\":" << result
         << ",\"message\":\""
         << (result == 0 ? "Image SDK 1.46.0 ready" : "OpenLibrary failed")
         << "\"}";
    return writeResult(json.str(), output, capacity);
}
