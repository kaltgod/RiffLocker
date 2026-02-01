#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle for the analyzer instance to Type safety in Dart
typedef void* AnalyzerHandle;

/**
 * Initializes the audio analyzer with specific sample rate and buffer size.
 * 
 * @param sampleRate The sample rate of the audio stream (e.g., 44100).
 * @param bufferSize The size of the audio buffer (e.g., 512, 1024).
 * @return A handle to the analyzer instance, or NULL if initialization failed.
 */
AnalyzerHandle createAnalyzer(int sampleRate, int bufferSize);

/**
 * Processes a block of audio samples to detect pitch.
 * 
 * @param analyzerInstance The handle returned by createAnalyzer.
 * @param inputBuffer Pointer to the array of float audio samples.
 * @param bufferSize The number of samples in the inputBuffer.
 * @return The detected frequency in Hz. Returns 0.0 if silent or uncertain.
 */
float processAudioBlock(AnalyzerHandle analyzerInstance, float* inputBuffer, int bufferSize);

/**
 * Destroys the analyzer instance and frees associated memory.
 * 
 * @param analyzerInstance The handle returned by createAnalyzer.
 */
void destroyAnalyzer(AnalyzerHandle analyzerInstance);

#ifdef __cplusplus
}
#endif
