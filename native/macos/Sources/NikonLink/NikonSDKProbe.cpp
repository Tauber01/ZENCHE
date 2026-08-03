#include <cstdio>
#include <cstring>
#include <fcntl.h>
#include <string>
#include <unistd.h>
#include <vector>

extern "C" int ZencheProbeNikonRemoteSDK(char* output, std::size_t capacity);
extern "C" int ZencheProbeNikonImageSDK(char* output, std::size_t capacity);

namespace {

class ScopedStdoutSilencer {
public:
    ScopedStdoutSilencer() {
        std::fflush(stdout);
        saved_ = dup(STDOUT_FILENO);
        const int nullOutput = open("/dev/null", O_WRONLY);
        if (saved_ >= 0 && nullOutput >= 0) {
            dup2(nullOutput, STDOUT_FILENO);
        }
        if (nullOutput >= 0) close(nullOutput);
    }

    ~ScopedStdoutSilencer() {
        std::fflush(stdout);
        if (saved_ >= 0) {
            dup2(saved_, STDOUT_FILENO);
            close(saved_);
        }
    }

    ScopedStdoutSilencer(const ScopedStdoutSilencer&) = delete;
    ScopedStdoutSilencer& operator=(const ScopedStdoutSilencer&) = delete;

private:
    int saved_ = -1;
};

}  // namespace

int main(int argc, char** argv) {
    if (argc != 2) {
        std::fputs("usage: ZENCHE-NikonSDKProbe <remote|image>\n", stderr);
        return 64;
    }

    std::vector<char> output(32'768, 0);
    const std::string kind(argv[1]);
    int result = 0;
    {
        // Nikon's runtime writes timing diagnostics to stdout. Keep stdout
        // machine-readable so the parent app receives one JSON document.
        ScopedStdoutSilencer silenceSDKOutput;
        if (kind == "remote") {
            result = ZencheProbeNikonRemoteSDK(output.data(), output.size());
        } else if (kind == "image") {
            result = ZencheProbeNikonImageSDK(output.data(), output.size());
        } else {
            std::fputs("unknown Nikon SDK probe kind\n", stderr);
            return 64;
        }
    }

    if (output[0] != '\0') {
        std::fwrite(output.data(), 1, std::strlen(output.data()), stdout);
    }
    return result == 0 ? 0 : 1;
}
