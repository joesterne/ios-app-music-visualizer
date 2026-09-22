#include "AGAnalyzer.h"
#include <math.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

#define N 2048
#define HOP 1024
#define PI 3.14159265358979323846
struct AGAnalyzer {
    pthread_mutex_t mutex;
    float ring[N], window[N], real[N], imag[N];
    float bands[AG_BANDS], wave[AG_WAVEFORM], levels[5];
    size_t cursor, count, hop;
    double rate;
};
static float clamp01(float x) { return fminf(1, fmaxf(0, x)); }
AGAnalyzer *AGAnalyzerCreate(void) {
    AGAnalyzer *a = calloc(1, sizeof(*a));
    if (!a) return NULL;
    pthread_mutex_init(&a->mutex, NULL);
    for (int i = 0; i < N; i++) a->window[i] = .5f - .5f * cosf(2 * PI * i / (N - 1));
    return a;
}
void AGAnalyzerDestroy(AGAnalyzer *a) {
    if (!a) return;
    pthread_mutex_destroy(&a->mutex);
    free(a);
}
static void resetUnlocked(AGAnalyzer *a) {
    memset(a->ring, 0, sizeof(a->ring));
    memset(a->bands, 0, sizeof(a->bands));
    memset(a->wave, 0, sizeof(a->wave));
    memset(a->levels, 0, sizeof(a->levels));
    a->cursor = a->count = a->hop = 0;
}
void AGAnalyzerReset(AGAnalyzer *a) {
    if (!a) return;
    pthread_mutex_lock(&a->mutex); resetUnlocked(a); pthread_mutex_unlock(&a->mutex);
}
static void transform(AGAnalyzer *a) {
    double energy = 0;
    float peak = 0;
    for (int i = 0; i < N; i++) {
        float x = a->ring[(a->cursor + i) % N];
        a->real[i] = x * a->window[i]; a->imag[i] = 0;
        energy += x * x; peak = fmaxf(peak, fabsf(x));
        if (i % (N / AG_WAVEFORM) == 0) a->wave[i / (N / AG_WAVEFORM)] = x;
    }
    for (unsigned i = 1, j = 0; i < N; i++) {
        unsigned bit = N >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) {
            float t = a->real[i]; a->real[i] = a->real[j]; a->real[j] = t;
        }
    }
    for (unsigned len = 2; len <= N; len <<= 1) {
        float angle = -2 * PI / len;
        float wr = cosf(angle), wi = sinf(angle);
        for (unsigned base = 0; base < N; base += len) {
            float ur = 1, ui = 0;
            for (unsigned j = 0; j < len / 2; j++) {
                unsigned p = base + j, q = p + len / 2;
                float vr = a->real[q] * ur - a->imag[q] * ui;
                float vi = a->real[q] * ui + a->imag[q] * ur;
                a->real[q] = a->real[p] - vr; a->imag[q] = a->imag[p] - vi;
                a->real[p] += vr; a->imag[p] += vi;
                float next = ur * wr - ui * wi; ui = ur * wi + ui * wr; ur = next;
            }
        }
    }
    double upper = fmin(16000, a->rate * .48);
    float sums[3] = {0}; int counts[3] = {0};
    for (int b = 0; b < AG_BANDS; b++) {
        double lo = 40 * pow(upper / 40, (double)b / AG_BANDS);
        double hi = 40 * pow(upper / 40, (double)(b + 1) / AG_BANDS);
        int first = (int)floor(lo * N / a->rate);
        int last = (int)ceil(hi * N / a->rate);
        first = first < 1 ? 1 : first; last = last >= N / 2 ? N / 2 - 1 : last;
        float magnitude = 0;
        for (int k = first; k <= last; k++)
            magnitude = fmaxf(magnitude, hypotf(a->real[k], a->imag[k]) * (4.f / N));
        float target = clamp01((20 * log10f(fmaxf(1e-7f, magnitude)) + 72) / 72);
        float blend = target > a->bands[b] ? .72f : .16f;
        a->bands[b] += blend * (target - a->bands[b]);
        int zone = hi < 250 ? 0 : (hi < 4000 ? 1 : 2);
        sums[zone] += a->bands[b]; counts[zone]++;
    }
    a->levels[0] = clamp01(sqrtf(energy / N)); a->levels[1] = clamp01(peak);
    for (int i = 0; i < 3; i++) a->levels[i + 2] = counts[i] ? sums[i] / counts[i] : 0;
}
static void push(AGAnalyzer *a, float x) {
    if (!isfinite(x)) x = 0;
    a->ring[a->cursor] = fmaxf(-1, fminf(1, x));
    a->cursor = (a->cursor + 1) % N; a->count++; a->hop++;
    if (a->count >= N && a->hop >= HOP) { a->hop = 0; transform(a); }
}
static int begin(AGAnalyzer *a, double rate) {
    if (!a || !isfinite(rate) || rate < 8000 || rate > 384000) return 0;
    pthread_mutex_lock(&a->mutex);
    if (a->rate != rate) { resetUnlocked(a); a->rate = rate; }
    return 1;
}
void AGAnalyzerPushPlanar(AGAnalyzer *a, const float *left, const float *right,
                          size_t frames, double rate) {
    if (!left || !begin(a, rate)) return;
    for (size_t i = 0; i < frames; i++) push(a, right ? (left[i] + right[i]) * .5f : left[i]);
    pthread_mutex_unlock(&a->mutex);
}
void AGAnalyzerPushInterleaved(AGAnalyzer *a, const float *samples,
                               size_t frames, unsigned channels, double rate) {
    if (!samples || channels == 0 || channels > 32 || !begin(a, rate)) return;
    for (size_t i = 0; i < frames; i++) {
        float sum = 0;
        for (unsigned c = 0; c < channels; c++) sum += samples[i * channels + c];
        push(a, sum / channels);
    }
    pthread_mutex_unlock(&a->mutex);
}
void AGAnalyzerCopyFrame(AGAnalyzer *a, float *bands, float *waveform, float *levels) {
    if (!a) return;
    pthread_mutex_lock(&a->mutex);
    if (bands) memcpy(bands, a->bands, sizeof(a->bands));
    if (waveform) memcpy(waveform, a->wave, sizeof(a->wave));
    if (levels) memcpy(levels, a->levels, sizeof(a->levels));
    pthread_mutex_unlock(&a->mutex);
}
