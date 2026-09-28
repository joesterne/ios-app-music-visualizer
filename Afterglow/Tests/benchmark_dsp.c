#define _POSIX_C_SOURCE 200809L
#include "AGAnalyzer.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static double now(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
}
static int compare(const void *a, const void *b) {
    double x = *(const double *)a, y = *(const double *)b;
    return (x > y) - (x < y);
}
int main(void) {
    enum { FRAMES = 1024, BLOCKS = 6000, TRIALS = 7 };
    const double rates[] = {44100, 48000, 96000};
    float samples[FRAMES * 2], bands[AG_BANDS], wave[AG_WAVEFORM], levels[5];
    for (size_t r = 0; r < sizeof(rates) / sizeof(rates[0]); r++) {
        for (int i = 0; i < FRAMES; i++) {
            samples[2 * i] = .4f * sin(i * .13) + .2f * cos(i * .033);
            samples[2 * i + 1] = .3f * cos(i * .078) - .15f * sin(i * .041);
        }
        double times[TRIALS];
        for (int trial = 0; trial < TRIALS; trial++) {
            AGAnalyzer *a = AGAnalyzerCreate();
            if (!a) return 1;
            for (int i = 0; i < 64; i++) AGAnalyzerPushInterleaved(a, samples, FRAMES, 2, rates[r]);
            double start = now();
            for (int i = 0; i < BLOCKS; i++) {
                AGAnalyzerPushInterleaved(a, samples, FRAMES, 2, rates[r]);
                AGAnalyzerCopyFrame(a, bands, wave, levels);
            }
            times[trial] = (now() - start) * 1e6 / BLOCKS;
            AGAnalyzerDestroy(a);
        }
        qsort(times, TRIALS, sizeof(*times), compare);
        printf("%.0f Hz: median %.3f us / stereo 1024-frame block + snapshot (range %.3f–%.3f; %d trials)\n",
               rates[r], times[TRIALS / 2], times[0], times[TRIALS - 1], TRIALS);
    }
}
