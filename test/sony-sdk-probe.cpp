#include <cstddef>
#include <iostream>
#include <vector>

extern "C" int ZencheProbeSonyCameraRemoteSDK(char*, std::size_t);

int main() {
    std::vector<char> output(32768, 0);
    const int result = ZencheProbeSonyCameraRemoteSDK(
        output.data(),
        output.size());
    std::cout << output.data() << '\n';
    return result;
}
