# Native Library Structure

The C++ code is organized as follows to support cross-platform compilation (Android & iOS) and Dart FFI integration.

## Directory Layout

```
/native_lib
|-- CMakeLists.txt        # Build configuration for CMake
|-- include
|   `-- audio_analyzer.h  # Public C header for Dart FFI
`-- src
    `-- audio_analyzer.cpp # C++ implementation and Aubio wrapper
```

## Integration Strategy

1.  **CMakeLists.txt**: Handles downloading Aubio (via FetchContent) and building it as a static library. It then builds `libaudio_analyzer` as a shared library linking Aubio.
2.  **Android**: The `CMakeLists.txt` can be included directly in `android/app/build.gradle` using `externalNativeBuild`.
3.  **iOS**: The `CMakeLists.txt` can be used to generate an Xcode project or framework, or integrated via a custom build script in the Podfile.
