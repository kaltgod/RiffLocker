#include "audio_analyzer.h"
#include <aubio.h>
#include <new>
#include <cstring> // for memcpy

struct Analyzer {
    aubio_pitch_t* pitch;
    fvec_t* input_vec;
    fvec_t* output_vec;
    int bufferSize;

    Analyzer(int sampleRate, int bufSize) : bufferSize(bufSize) {
        // Aubio Pitch Detection
        // method: "default" (usually yinfft)
        // buf_size: The size of the buffer to analyze
        // hop_size: The step size (usually same as buffer size for block processing)
        // sample_rate: Audio sample rate
        
        // Note: hop_size determines how many new samples are read. 
        // If we process blocks of 'bufSize', hop_size should be 'bufSize'.
        uint_t hop_s = (uint_t)bufSize; 
        // Window size should be larger than hop size (e.g. 2x) for better pitch detection stability
        // especially for low frequencies. YIN algorithm benefits from overlap.
        uint_t win_s = (uint_t)bufSize * 2; 
        
        // Use "yin" algorithm - generally better for guitar/string instruments than default (yinfft)
        pitch = new_aubio_pitch("yin", win_s, hop_s, (uint_t)sampleRate);
        
        // specific configuration for guitar
        if (pitch) {
            // Set silence threshold (in dB). 
            // -100dB (effectively off). We will handle silence detection in Dart (RMS)
            // to allow for easier tuning without C++ recompilation.
            aubio_pitch_set_silence(pitch, -100);
        }

        // Allocate fvecs for aubio
        input_vec = new_fvec(hop_s);
        output_vec = new_fvec(1); // Pitch output is a single value
    }

    ~Analyzer() {
        if (pitch) del_aubio_pitch(pitch);
        if (input_vec) del_fvec(input_vec);
        if (output_vec) del_fvec(output_vec);
    }

    float process(float* buffer, int size) {
        if (!pitch || !input_vec || !output_vec) return 0.0f;
        
        // Ensure we don't overflow the internal buffer
        int copySize = (size < (int)input_vec->length) ? size : (int)input_vec->length;

        // Copy input data to aubio vector
        // fvec_t->data is a float*
        std::memcpy(input_vec->data, buffer, copySize * sizeof(float));

        // Zero out remaining if buffer is smaller (unlikely in block processing)
        if (copySize < (int)input_vec->length) {
             std::memset(input_vec->data + copySize, 0, (input_vec->length - copySize) * sizeof(float));
        }

        // Execute pitch detection
        aubio_pitch_do(pitch, input_vec, output_vec);

        // Check confidence
        float confidence = aubio_pitch_get_confidence(pitch);

        if (confidence > 0.6f) {
            // Result is in the first element
            return output_vec->data[0];
        } else {
            return 0.0f;
        }
    }
};

extern "C" {

    AnalyzerHandle createAnalyzer(int sampleRate, int bufferSize) {
        try {
            return new Analyzer(sampleRate, bufferSize);
        } catch (...) {
            return nullptr;
        }
    }

    float processAudioBlock(AnalyzerHandle analyzerInstance, float* inputBuffer, int bufferSize) {
        if (!analyzerInstance || !inputBuffer) return 0.0f;
        
        auto analyzer = static_cast<Analyzer*>(analyzerInstance);
        return analyzer->process(inputBuffer, bufferSize);
    }

    void destroyAnalyzer(AnalyzerHandle analyzerInstance) {
        if (analyzerInstance) {
            auto analyzer = static_cast<Analyzer*>(analyzerInstance);
            delete analyzer;
        }
    }

}
