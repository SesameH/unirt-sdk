# Copyright (c) 2026 Peter Huang.
# SPDX-License-Identifier: BSD-3-Clause
#
# Builds only the thin JNI glue (unirt_jni.cpp) against the prebuilt
# libunirt.so shipped in ../prebuilt/${ANDROID_ABI}/ (see README). The SDK
# implementation itself is closed-source and lives in a separate private
# repo; only its frozen public C header (../../include/unirt.h) and the
# compiled library are needed to build this glue layer.
#
#   cmake -S bindings/android/jni -B build-android \
#     -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
#     -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-28 \
#     -DCMAKE_BUILD_TYPE=Release
#   cmake --build build-android -j
#
# Output: libunirt_jni.so. Ship alongside the prebuilt libunirt.so /
# libunirt_plugin_llama_cpp.so / llama.cpp's own libs in jniLibs/arm64-v8a.

cmake_minimum_required(VERSION 3.22)
project(unirt-android-jni CXX)

get_filename_component(UNIRT_SDK_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../.." ABSOLUTE)

add_library(unirt SHARED IMPORTED)
set_target_properties(unirt PROPERTIES
    IMPORTED_LOCATION "${UNIRT_SDK_ROOT}/android/prebuilt/${ANDROID_ABI}/libunirt.so")

add_library(unirt_jni SHARED unirt_jni.cpp)
target_include_directories(unirt_jni PRIVATE "${UNIRT_SDK_ROOT}/include")
target_link_libraries(unirt_jni PRIVATE unirt)
target_compile_definitions(unirt_jni PRIVATE UNIRT_SHARED)
