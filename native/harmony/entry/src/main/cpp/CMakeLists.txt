cmake_minimum_required(VERSION 3.5.0)
project(timelapse)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})
include_directories(${NATIVERENDER_ROOT_PATH})

add_library(timelapse SHARED timelapse_encoder.cpp)

target_link_libraries(timelapse PUBLIC
    libace_napi.z.so
    libnative_media_venc.so
    libnative_media_codecbase.so
    libnative_media_core.so
    libnative_media_avmuxer.so
)
