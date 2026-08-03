#include <libusb.h>

#include <algorithm>
#include <array>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

constexpr std::uint16_t kNikonVendor = 0x04b0;
constexpr std::uint8_t kStillImageClass = 6;
constexpr std::uint16_t kContainerCommand = 1;
constexpr std::uint16_t kContainerData = 2;
constexpr std::uint16_t kContainerResponse = 3;
constexpr std::uint16_t kOpenSession = 0x1002;
constexpr std::uint16_t kCloseSession = 0x1003;
constexpr std::uint16_t kGetDevicePropertyValue = 0x1015;
constexpr std::uint16_t kSetDevicePropertyValue = 0x1016;
constexpr std::uint16_t kResponseOK = 0x2001;
constexpr std::uint32_t kMovieFileType = 0x0000d0af;
constexpr std::uint32_t kMovieProResToneMode = 0x0001d000;
constexpr std::uint32_t kMovieH265ToneMode = 0x0001d001;
constexpr std::uint32_t kMovieNRawToneMode = 0x0001d028;
constexpr std::uint32_t kMovieProResRawToneMode = 0x0001d029;

constexpr std::uint32_t kH264EightBit = 0x00000801;
constexpr std::uint32_t kH265EightBit = 0x00010800;
constexpr std::uint32_t kH265TenBit = 0x00010a00;
constexpr std::uint32_t kNRawTwelveBit = 0x00020c02;
constexpr std::uint32_t kProRes422TenBit = 0x00100a00;
constexpr std::uint32_t kProResRawTwelveBit = 0x00110c00;

void append16(std::vector<std::uint8_t>& bytes, std::uint16_t value) {
    bytes.push_back(static_cast<std::uint8_t>(value));
    bytes.push_back(static_cast<std::uint8_t>(value >> 8));
}

void append32(std::vector<std::uint8_t>& bytes, std::uint32_t value) {
    bytes.push_back(static_cast<std::uint8_t>(value));
    bytes.push_back(static_cast<std::uint8_t>(value >> 8));
    bytes.push_back(static_cast<std::uint8_t>(value >> 16));
    bytes.push_back(static_cast<std::uint8_t>(value >> 24));
}

std::uint16_t read16(const std::uint8_t* bytes) {
    return static_cast<std::uint16_t>(bytes[0]) |
        (static_cast<std::uint16_t>(bytes[1]) << 8);
}

std::uint32_t read32(const std::uint8_t* bytes) {
    return static_cast<std::uint32_t>(bytes[0]) |
        (static_cast<std::uint32_t>(bytes[1]) << 8) |
        (static_cast<std::uint32_t>(bytes[2]) << 16) |
        (static_cast<std::uint32_t>(bytes[3]) << 24);
}

struct Container {
    std::uint16_t type = 0;
    std::uint16_t code = 0;
    std::uint32_t transaction = 0;
    std::vector<std::uint8_t> payload;
};

class NikonPTPSession {
public:
    NikonPTPSession() {
        const int result = libusb_init(&context_);
        if (result != LIBUSB_SUCCESS) {
            throw std::runtime_error("无法初始化 USB：" + errorName(result));
        }
        openCamera();
        openSession();
    }

    ~NikonPTPSession() {
        try {
            if (sessionOpen_) transact(kCloseSession, {}, {});
        } catch (...) {
        }
        if (handle_ != nullptr && interfaceNumber_ >= 0) {
            libusb_release_interface(handle_, interfaceNumber_);
        }
        if (handle_ != nullptr) libusb_close(handle_);
        if (context_ != nullptr) libusb_exit(context_);
    }

    void setNLog(bool enabled) {
        const auto movieTypeData = transact(
            kGetDevicePropertyValue,
            {kMovieFileType},
            {});
        if (movieTypeData.size() < 4) {
            throw std::runtime_error("相机未返回有效的视频编码值");
        }
        const std::uint32_t movieType = read32(movieTypeData.data());
        const std::uint32_t toneProperty = tonePropertyFor(movieType, enabled);
        if (toneProperty == 0) return;
        transact(
            kSetDevicePropertyValue,
            {toneProperty},
            {static_cast<std::uint8_t>(enabled ? 1 : 0)});
        std::cout << "{\"movieFileType\":" << movieType
                  << ",\"toneProperty\":" << toneProperty
                  << ",\"nlog\":" << (enabled ? "true" : "false")
                  << "}\n";
    }

private:
    static std::string errorName(int code) {
        const char* name = libusb_error_name(code);
        return name == nullptr ? std::to_string(code) : name;
    }

    static std::uint32_t tonePropertyFor(
        std::uint32_t movieType,
        bool enabled) {
        switch (movieType) {
            case kH265TenBit: return kMovieH265ToneMode;
            case kNRawTwelveBit: return kMovieNRawToneMode;
            case kProRes422TenBit: return kMovieProResToneMode;
            case kProResRawTwelveBit: return kMovieProResRawToneMode;
            case kH264EightBit:
            case kH265EightBit:
                if (!enabled) return 0;
                throw std::runtime_error(
                    "当前编码不支持 N-Log；请选择 H.265 10-bit、N-RAW、"
                    "ProRes 422 HQ 或 ProRes RAW");
            default:
                throw std::runtime_error(
                    "当前视频编码未提供可写的 N-Log ToneMode 属性（值 " +
                    std::to_string(movieType) + "）");
        }
    }

    void openCamera() {
        libusb_device** devices = nullptr;
        const ssize_t count = libusb_get_device_list(context_, &devices);
        if (count < 0) {
            throw std::runtime_error("无法枚举 USB 设备");
        }
        for (ssize_t index = 0; index < count && handle_ == nullptr; ++index) {
            libusb_device* device = devices[index];
            libusb_device_descriptor descriptor{};
            if (libusb_get_device_descriptor(device, &descriptor) !=
                    LIBUSB_SUCCESS ||
                descriptor.idVendor != kNikonVendor) {
                continue;
            }
            libusb_config_descriptor* config = nullptr;
            if (libusb_get_active_config_descriptor(device, &config) !=
                LIBUSB_SUCCESS) {
                continue;
            }
            for (std::uint8_t interfaceIndex = 0;
                 interfaceIndex < config->bNumInterfaces && handle_ == nullptr;
                 ++interfaceIndex) {
                const libusb_interface& interface =
                    config->interface[interfaceIndex];
                for (int alternateIndex = 0;
                     alternateIndex < interface.num_altsetting;
                     ++alternateIndex) {
                    const libusb_interface_descriptor& alternate =
                        interface.altsetting[alternateIndex];
                    if (alternate.bInterfaceClass != kStillImageClass) continue;
                    std::uint8_t input = 0;
                    std::uint8_t output = 0;
                    for (std::uint8_t endpointIndex = 0;
                         endpointIndex < alternate.bNumEndpoints;
                         ++endpointIndex) {
                        const libusb_endpoint_descriptor& endpoint =
                            alternate.endpoint[endpointIndex];
                        if ((endpoint.bmAttributes & LIBUSB_TRANSFER_TYPE_MASK) !=
                            LIBUSB_TRANSFER_TYPE_BULK) {
                            continue;
                        }
                        if ((endpoint.bEndpointAddress & LIBUSB_ENDPOINT_DIR_MASK) ==
                            LIBUSB_ENDPOINT_IN) {
                            input = endpoint.bEndpointAddress;
                        } else {
                            output = endpoint.bEndpointAddress;
                        }
                    }
                    if (input == 0 || output == 0) continue;
                    libusb_device_handle* candidate = nullptr;
                    if (libusb_open(device, &candidate) != LIBUSB_SUCCESS) continue;
                    libusb_set_auto_detach_kernel_driver(candidate, 1);
                    const int claim = libusb_claim_interface(
                        candidate,
                        alternate.bInterfaceNumber);
                    if (claim != LIBUSB_SUCCESS) {
                        libusb_close(candidate);
                        continue;
                    }
                    handle_ = candidate;
                    interfaceNumber_ = alternate.bInterfaceNumber;
                    bulkInput_ = input;
                    bulkOutput_ = output;
                    break;
                }
            }
            libusb_free_config_descriptor(config);
        }
        libusb_free_device_list(devices, 1);
        if (handle_ == nullptr) {
            throw std::runtime_error(
                "未找到可独占访问的 Nikon USB/PTP 相机；请关闭照片、"
                "NX Tether 等占用相机的软件");
        }
    }

    void openSession() {
        transact(kOpenSession, {1}, {});
        sessionOpen_ = true;
    }

    std::vector<std::uint8_t> transact(
        std::uint16_t operation,
        const std::vector<std::uint32_t>& parameters,
        const std::vector<std::uint8_t>& outgoingData) {
        const std::uint32_t transaction = operation == kOpenSession
            ? 0
            : ++transaction_;
        std::vector<std::uint8_t> parameterData;
        for (const std::uint32_t parameter : parameters) {
            append32(parameterData, parameter);
        }
        send(kContainerCommand, operation, transaction, parameterData);
        if (!outgoingData.empty()) {
            send(kContainerData, operation, transaction, outgoingData);
        }
        Container first = receive();
        std::vector<std::uint8_t> data;
        Container response = first;
        if (first.type == kContainerData) {
            data = std::move(first.payload);
            response = receive();
        }
        if (response.type != kContainerResponse ||
            response.transaction != transaction) {
            throw std::runtime_error("相机返回了无效的 PTP 响应");
        }
        if (response.code != kResponseOK) {
            throw std::runtime_error(
                "相机拒绝 N-Log 设置（PTP 响应 0x" +
                hex(response.code) + "）");
        }
        return data;
    }

    void send(
        std::uint16_t type,
        std::uint16_t code,
        std::uint32_t transaction,
        const std::vector<std::uint8_t>& payload) {
        std::vector<std::uint8_t> bytes;
        append32(bytes, static_cast<std::uint32_t>(12 + payload.size()));
        append16(bytes, type);
        append16(bytes, code);
        append32(bytes, transaction);
        bytes.insert(bytes.end(), payload.begin(), payload.end());
        std::size_t offset = 0;
        while (offset < bytes.size()) {
            int transferred = 0;
            const int result = libusb_bulk_transfer(
                handle_,
                bulkOutput_,
                bytes.data() + offset,
                static_cast<int>(bytes.size() - offset),
                &transferred,
                10'000);
            if (result != LIBUSB_SUCCESS || transferred <= 0) {
                throw std::runtime_error("发送 PTP 数据失败：" + errorName(result));
            }
            offset += static_cast<std::size_t>(transferred);
        }
    }

    Container receive() {
        std::vector<std::uint8_t> bytes(1024 * 1024);
        int transferred = 0;
        const int result = libusb_bulk_transfer(
            handle_,
            bulkInput_,
            bytes.data(),
            static_cast<int>(bytes.size()),
            &transferred,
            10'000);
        if (result != LIBUSB_SUCCESS || transferred < 12) {
            throw std::runtime_error("读取 PTP 数据失败：" + errorName(result));
        }
        const std::uint32_t length = read32(bytes.data());
        if (length < 12 || length > static_cast<std::uint32_t>(transferred)) {
            throw std::runtime_error("相机返回了不完整的 PTP 容器");
        }
        Container resultContainer;
        resultContainer.type = read16(bytes.data() + 4);
        resultContainer.code = read16(bytes.data() + 6);
        resultContainer.transaction = read32(bytes.data() + 8);
        resultContainer.payload.assign(bytes.begin() + 12, bytes.begin() + length);
        return resultContainer;
    }

    static std::string hex(std::uint16_t value) {
        constexpr char digits[] = "0123456789ABCDEF";
        std::string result(4, '0');
        for (int index = 3; index >= 0; --index) {
            result[index] = digits[value & 0x0f];
            value >>= 4;
        }
        return result;
    }

    libusb_context* context_ = nullptr;
    libusb_device_handle* handle_ = nullptr;
    int interfaceNumber_ = -1;
    std::uint8_t bulkInput_ = 0;
    std::uint8_t bulkOutput_ = 0;
    std::uint32_t transaction_ = 0;
    bool sessionOpen_ = false;
};

}  // namespace

int main(int argc, char** argv) {
    if (argc != 3 || std::string(argv[1]) != "set-nlog" ||
        (std::string(argv[2]) != "on" && std::string(argv[2]) != "off")) {
        std::cerr << "usage: zenche-nikon-ptp set-nlog on|off\n";
        return 64;
    }
    try {
        NikonPTPSession session;
        session.setNLog(std::string(argv[2]) == "on");
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
