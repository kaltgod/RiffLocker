cmake_minimum_required(VERSION 3.10)

project(audio_analyzer LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)

# --- Aubio Configuration ---
# We build Aubio from source to avoid external dependencies like Waf or Python.

include(FetchContent)
FetchContent_Declare(
    aubio
    GIT_REPOSITORY https://github.com/aubio/aubio.git
    GIT_TAG        0.4.9
)

FetchContent_GetProperties(aubio)
if(NOT aubio_POPULATED)
    FetchContent_Populate(aubio)
endif()

# Generate a minimal config.h required by Aubio
# We assume standard C library usage.
set(AUBIO_CONFIG_H "${CMAKE_CURRENT_BINARY_DIR}/include/config.h")
if(NOT EXISTS ${AUBIO_CONFIG_H})
    file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/include")
    file(WRITE ${AUBIO_CONFIG_H} "
#ifndef CONFIG_H
#define CONFIG_H
#define HAVE_STDLIB_H 1
#define HAVE_STDIO_H 1
#define HAVE_MATH_H 1
#define HAVE_STRING_H 1
#define HAVE_LIMITS_H 1
#define HAVE_STDARG_H 1
#define HAVE_C99_VARARGS_MACROS 1
#endif
")
endif()

# define sources manually similar to how aubio's waf wscripts do
# This includes all standard source files.
file(GLOB_RECURSE AUBIO_SRCS 
    "${aubio_SOURCE_DIR}/src/*.c"
)

# Create Aubio static library
add_library(aubio STATIC ${AUBIO_SRCS})

target_include_directories(aubio PUBLIC 
    "${aubio_SOURCE_DIR}/src" # To allow #include "aubio.h"
    "${CMAKE_CURRENT_BINARY_DIR}/include" # For config.h
)
target_compile_definitions(aubio PRIVATE HAVE_CONFIG_H=1)

# Platform-specific flags
if(ANDROID)
    target_compile_definitions(aubio PRIVATE HAVE_ANDROID=1)
    # Android logging if needed by aubio (unlikely but good practice)
    find_library(log-lib log)
elseif(APPLE)
    target_compile_definitions(aubio PRIVATE HAVE_ACCELERATE=1)
    target_link_libraries(aubio "-framework Accelerate" "-framework AudioToolbox")
else()
    # Desktop defaults
    target_compile_definitions(aubio PRIVATE HAVE_MATH_H=1)
endif()


# --- Audio Analyzer Wrapper ---

# Enable symbol export for Windows (creates import library .lib)
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

add_library(audio_analyzer SHARED
    src/audio_analyzer.cpp
)

# Include directories
target_include_directories(audio_analyzer PUBLIC 
    "include"
    "${aubio_SOURCE_DIR}/src"
)

# Link against Aubio
target_link_libraries(audio_analyzer PRIVATE aubio)

# Link system libraries
if(ANDROID)
    target_link_libraries(audio_analyzer PRIVATE ${log-lib})
endif()

