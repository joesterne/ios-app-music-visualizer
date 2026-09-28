#include "AGAnalyzer.h"
#include <math.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

#define N 2048
#define HOP 1024
#define PI 3.14159265358979323846
struct AGAnalyzer {
    /* Input/reset serialization is independent of the short display-copy lock. */
    pthread_mutex_t inputMutex, frameMutex;
    float ring[N], window[N], real[N], imag[N];
    float twiddleReal[N - 1], twiddleImag[N - 1];
    unsigned reverse[N];
    int first[AG_BANDS], last[AG_BANDS], zone[AG_BANDS], zoneCounts[3];
    float bands[AG_BANDS], wave[AG_WAVEFORM], levels[5];
    float publishedBands[AG_BANDS], publishedWave[AG_WAVEFORM], publishedLevels[5];
    size_t cursor, count, hop;
    double rate;
};
static float clamp01(float x) { return fminf(1, fmaxf(0, x)); }
AGAnalyzer *AGAnalyzerCreate(void) {
    AGAnalyzer *a = calloc(1, sizeof(*a));
    if (!a) return NULL;
    if (pthread_mutex_init(&a->inputMutex, NULL) != 0) { free(a); return NULL; }
    if (pthread_mutex_init(&a->frameMutex, NULL) != 0) {
        pthread_mutex_destroy(&a->inputMutex); free(a); return NULL;
    }
    for (unsigned i = 0; i < N; i++) {
        a->window[i] = .5f - .5f * cosf(2 * PI * i / (N - 1));
        unsigned value = i, reversed = 0;
        for (unsigned bit = N >> 1; bit; bit >>= 1) {
            if (value & 1) reversed |= bit;
            value >>= 1;
        }
        a->reverse[i] = reversed;
    }
    /* Stage-local tables preserve the old recurrence, but compute it only once. */
    unsigned offset = 0;
    for (unsigned len = 2; len <= N; len <<= 1) {
        float angle = -2 * PI / len, wr = cosf(angle), wi = sinf(angle);
        float ur = 1, ui = 0;
        for (unsigned j = 0; j < len / 2; j++) {
            a->twiddleReal[offset + j] = ur; a->twiddleImag[offset + j] = ui;
            float next = ur * wr - ui * wi; ui = ur * wi + ui * wr; ur = next;
        }
        offset += len / 2;
    }
    return a;
}
void AGAnalyzerDestroy(AGAnalyzer *a) {
    if (!a) return;
    pthread_mutex_destroy(&a->inputMutex); pthread_mutex_destroy(&a->frameMutex);
    free(a);
}
static void publishUnlocked(AGAnalyzer *a) {
    memcpy(a->publishedBands, a->bands, sizeof(a->bands));
    memcpy(a->publishedWave, a->wave, sizeof(a->wave));
    memcpy(a->publishedLevels, a->levels, sizeof(a->levels));
}
static void resetUnlocked(AGAnalyzer *a) {
    memset(a->ring, 0, sizeof(a->ring));
    memset(a->bands, 0, sizeof(a->bands));
    memset(a->wave, 0, sizeof(a->wave));
    memset(a->levels, 0, sizeof(a->levels));
    a->cursor = a->count = a->hop = 0;
    pthread_mutex_lock(&a->frameMutex);
    publishUnlocked(a);
    pthread_mutex_unlock(&a->frameMutex);
}
void AGAnalyzerReset(AGAnalyzer *a) {
    if (!a) return;
    pthread_mutex_lock(&a->inputMutex); resetUnlocked(a); pthread_mutex_unlock(&a->inputMutex);
}
static void configureBands(AGAnalyzer *a) {
    double upper = fmin(16000, a->rate * .48);
    memset(a->zoneCounts, 0, sizeof(a->zoneCounts));
    for (int b = 0; b < AG_BANDS; b++) {
        double lo = 40 * pow(upper / 40, (double)b / AG_BANDS);
        double hi = 40 * pow(upper / 40, (double)(b + 1) / AG_BANDS);
        int first = (int)floor(lo * N / a->rate), last = (int)ceil(hi * N / a->rate);
        a->first[b] = first < 1 ? 1 : first;
        a->last[b] = last >= N / 2 ? N / 2 - 1 : last;
        a->zone[b] = hi < 250 ? 0 : (hi < 4000 ? 1 : 2);
        a->zoneCounts[a->zone[b]]++;
    }
}
static void transform(AGAnalyzer *a) {
    double energy = 0;
    float peak = 0;
    memset(a->imag, 0, sizeof(a->imag));
    for (unsigned i = 0; i < N; i++) {
        float x = a->ring[(a->cursor + i) & (N - 1)];
        a->real[a->reverse[i]] = x * a->window[i];
        energy += x * x; peak = fmaxf(peak, fabsf(x));
        if (i % (N / AG_WAVEFORM) == 0) a->wave[i / (N / AG_WAVEFORM)] = x;
    }
    unsigned offset = 0;
    for (unsigned len = 2; len <= N; len <<= 1) {
        for (unsigned base = 0; base < N; base += len) {
            for (unsigned j = 0; j < len / 2; j++) {
                unsigned p = base + j, q = p + len / 2;
                float ur = a->twiddleReal[offset + j], ui = a->twiddleImag[offset + j];
                float vr = a->real[q] * ur - a->imag[q] * ui;
                float vi = a->real[q] * ui + a->imag[q] * ur;
                a->real[q] = a->real[p] - vr; a->imag[q] = a->imag[p] - vi;
                a->real[p] += vr; a->imag[p] += vi;
            }
        }
        offset += len / 2;
    }
    float sums[3] = {0};
    for (int b = 0; b < AG_BANDS; b++) {
        float power = 0;
        for (int k = a->first[b]; k <= a->last[b]; k++)
            power = fmaxf(power, a->real[k] * a->real[k] + a->imag[k] * a->imag[k]);
        /* sqrt(max(power)) equals max(magnitude): one root per band, not per bin. */
        float magnitude = sqrtf(power) * (4.f / N);
        float target = clamp01((20 * log10f(fmaxf(1e-7f, magnitude)) + 72) / 72);
        float blend = target > a->bands[b] ? .72f : .16f;
        a->bands[b] += blend * (target - a->bands[b]);
        sums[a->zone[b]] += a->bands[b];
    }
    a->levels[0] = clamp01(sqrtf(energy / N)); a->levels[1] = clamp01(peak);
    for (int i = 0; i < 3; i++) a->levels[i + 2] = a->zoneCounts[i] ? sums[i] / a->zoneCounts[i] : 0;
    /* A display reader must never make the FFT producer wait. Keep the previous
       complete display frame if a copy is in progress; publish at the next hop. */
    if (pthread_mutex_trylock(&a->frameMutex) == 0) {
        publishUnlocked(a); pthread_mutex_unlock(&a->frameMutex);
    }
}
static void push(AGAnalyzer *a, float x) {
    if (!isfinite(x)) x = 0;
    a->ring[a->cursor] = fmaxf(-1, fminf(1, x));
    a->cursor = (a->cursor + 1) & (N - 1);
    if (a->count < N) a->count++;
    a->hop++;
    if (a->count >= N && a->hop >= HOP) { a->hop = 0; transform(a); }
}
static int begin(AGAnalyzer *a, double rate) {
    if (!a || !isfinite(rate) || rate < 8000 || rate > 384000) return 0;
    pthread_mutex_lock(&a->inputMutex);
    if (a->rate != rate) { resetUnlocked(a); a->rate = rate; configureBands(a); }
    return 1;
}
void AGAnalyzerPushPlanar(AGAnalyzer *a, const float *left, const float *right,
                          size_t frames, double rate) {
    if (!left || !begin(a, rate)) return;
    for (size_t i = 0; i < frames; i++) push(a, right ? (left[i] + right[i]) * .5f : left[i]);
    pthread_mutex_unlock(&a->inputMutex);
}
void AGAnalyzerPushInterleaved(AGAnalyzer *a, const float *samples,
                               size_t frames, unsigned channels, double rate) {
    if (!samples || channels == 0 || channels > 32 || !begin(a, rate)) return;
    for (size_t i = 0; i < frames; i++) {
        float sum = 0;
        for (unsigned c = 0; c < channels; c++) sum += samples[i * channels + c];
        push(a, sum / channels);
    }
    pthread_mutex_unlock(&a->inputMutex);
}
void AGAnalyzerCopyFrame(AGAnalyzer *a, float *bands, float *waveform, float *levels) {
    if (!a) return;
    pthread_mutex_lock(&a->frameMutex);
    if (bands) memcpy(bands, a->publishedBands, sizeof(a->bands));
    if (waveform) memcpy(waveform, a->publishedWave, sizeof(a->wave));
    if (levels) memcpy(levels, a->publishedLevels, sizeof(a->levels));
    pthread_mutex_unlock(&a->frameMutex);
}
