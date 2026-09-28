#ifndef AG_ANALYZER_H
#define AG_ANALYZER_H
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
#define AG_BANDS 64
#define AG_WAVEFORM 256
typedef struct AGAnalyzer AGAnalyzer;
AGAnalyzer *AGAnalyzerCreate(void);
void AGAnalyzerDestroy(AGAnalyzer *analyzer);
void AGAnalyzerReset(AGAnalyzer *analyzer);
void AGAnalyzerPushPlanar(AGAnalyzer *analyzer, const float *left, const float *right,
                          size_t frames, double sampleRate);
void AGAnalyzerPushInterleaved(AGAnalyzer *analyzer, const float *samples,
                               size_t frames, unsigned channels, double sampleRate);
/* Copies the latest complete display frame without waiting for FFT computation.
   A contended display copy can defer publication until a later hop.
   levels: linear RMS, peak, bass, mid, treble. Bands/levels: 0...1; waveform: -1...1.
   All outputs are finite. Stop all callers before destroying the analyzer. */
void AGAnalyzerCopyFrame(AGAnalyzer *analyzer, float *bands, float *waveform, float *levels);
#ifdef __cplusplus
}
#endif
#endif
