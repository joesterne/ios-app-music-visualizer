#include "AGAnalyzer.h"
#include <assert.h>
#include <math.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>

#define PI 3.14159265358979323846
#define COUNT 16384
static void valid(const float *x, size_t count, int signedValue) {
    for (size_t i = 0; i < count; i++) {
        assert(isfinite(x[i])); assert(x[i] <= 1.0001f); assert(x[i] >= (signedValue ? -1.0001f : 0));
    }
}
static void tone(float *x, double freq, double rate) {
    for (int i = 0; i < COUNT; i++) x[i] = .5f * sin(2 * PI * freq * i / rate);
}
static void checkTone(double rate, double frequency) {
    AGAnalyzer *a = AGAnalyzerCreate(); assert(a);
    float *input = malloc(COUNT * sizeof(float)); assert(input);
    tone(input, frequency, rate);
    AGAnalyzerPushPlanar(a, input, NULL, COUNT, rate);
    float bands[64], wave[256], levels[5];
    AGAnalyzerCopyFrame(a, bands, wave, levels);
    valid(bands, 64, 0); valid(wave, 256, 1); valid(levels, 5, 0);
    assert(fabsf(levels[0] - .35355f) < .015f);
    assert(fabsf(levels[1] - .5f) < .015f);
    int strongest = 0;
    for (int i = 1; i < 64; i++) if (bands[i] > bands[strongest]) strongest = i;
    double upper = fmin(16000, rate * .48);
    double bandCenter = 40 * pow(upper / 40, (strongest + .5) / 64);
    assert(fabs(log2(bandCenter / frequency)) < .7);
    AGAnalyzerReset(a);
    AGAnalyzerCopyFrame(a, bands, wave, levels);
    for (int i = 0; i < 64; i++) assert(bands[i] == 0);
    for (int i = 0; i < 5; i++) assert(levels[i] == 0);
    free(input); AGAnalyzerDestroy(a);
}
typedef struct { AGAnalyzer *a; float *samples; } Shared;
static void *writer(void *raw) {
    Shared *s = raw;
    for (int i = 0; i < 200; i++) AGAnalyzerPushPlanar(s->a, s->samples, NULL, 1024, 48000);
    return NULL;
}
int main(void) {
    const double rates[] = {8000, 44100, 48000, 96000};
    for (int i = 0; i < 4; i++) { checkTone(rates[i], 440); checkTone(rates[i], 2200); }
    checkTone(48000, 90); checkTone(48000, 10000);
    AGAnalyzer *a = AGAnalyzerCreate(), *b = AGAnalyzerCreate();
    float *mono = calloc(COUNT, sizeof(float));
    float *stereo = calloc(COUNT * 2, sizeof(float));
    float bands[64], wave[256], levels[5], other[64];
    AGAnalyzerPushPlanar(a, mono, NULL, COUNT, 48000);
    AGAnalyzerCopyFrame(a, bands, wave, levels);
    for (int i = 0; i < 64; i++) assert(bands[i] == 0);
    assert(levels[0] == 0);
    tone(mono, 1000, 48000);
    for (int i = 0; i < COUNT; i++) stereo[i * 2] = stereo[i * 2 + 1] = mono[i];
    AGAnalyzerReset(a);
    AGAnalyzerPushPlanar(a, mono, mono, COUNT, 48000);
    AGAnalyzerPushInterleaved(b, stereo, COUNT, 2, 48000);
    AGAnalyzerCopyFrame(a, bands, wave, levels);
    AGAnalyzerCopyFrame(b, other, NULL, NULL);
    for (int i = 0; i < 64; i++) assert(fabsf(bands[i] - other[i]) < 1e-5f);
    // Silence must settle after an audible source; stale spectrum must not remain.
    for (int i = 0; i < COUNT; i++) mono[i] = 0;
    for (int i = 0; i < 8; i++) AGAnalyzerPushPlanar(a, mono, NULL, COUNT, 48000);
    AGAnalyzerCopyFrame(a, bands, wave, levels);
    assert(levels[0] == 0);
    for (int i = 0; i < 64; i++) assert(bands[i] < 0.0001f);
    // Malformed input cannot propagate NaN/Inf to geometry.
    for (int i = 0; i < COUNT; i++) mono[i] = i % 2 ? NAN : INFINITY;
    AGAnalyzerPushPlanar(a, mono, NULL, COUNT, 48000);
    AGAnalyzerPushInterleaved(a, stereo, COUNT, 0, 48000);
    AGAnalyzerPushPlanar(a, mono, NULL, COUNT, NAN);
    AGAnalyzerCopyFrame(a, bands, wave, levels);
    valid(bands, 64, 0); valid(wave, 256, 1); valid(levels, 5, 0);
    tone(mono, 440, 48000);
    Shared shared = {a, mono}; pthread_t thread;
    assert(pthread_create(&thread, NULL, writer, &shared) == 0);
    for (int i = 0; i < 200; i++) {
        AGAnalyzerCopyFrame(a, bands, wave, levels); valid(bands, 64, 0); valid(levels, 5, 0);
        if (i % 25 == 0) AGAnalyzerReset(a);
    }
    pthread_join(thread, NULL);
    AGAnalyzerDestroy(a); AGAnalyzerDestroy(b); free(mono); free(stereo);
    puts("PASS: tone frequency/RMS at four rates; silence; stereo formats; reset; non-finite input; concurrent snapshots.");
    return 0;
}
