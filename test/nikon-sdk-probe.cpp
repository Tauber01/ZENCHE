#include <cstdlib>
#include <iostream>

extern "C" int ZencheProbeNikonRemoteSDK(char*, std::size_t);
extern "C" int ZencheProbeNikonImageSDK(char*, std::size_t);

int main() {
    char remote[32768]{};
    char image[32768]{};
    const int remoteResult = ZencheProbeNikonRemoteSDK(remote, sizeof(remote));
    const int imageResult = ZencheProbeNikonImageSDK(image, sizeof(image));
    std::cout << "REMOTE=" << remote << '\n';
    std::cout << "IMAGE=" << image << '\n';
    return remoteResult == 0 && imageResult == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
