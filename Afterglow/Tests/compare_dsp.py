#!/usr/bin/env python3
"""Compare this analyzer with an earlier AGAnalyzer.c (no third-party packages)."""
import ctypes as C
import math
from pathlib import Path
import random
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
if len(sys.argv) != 2:
    raise SystemExit('Usage: python3 Tests/compare_dsp.py /path/to/previous/AGAnalyzer.c')
FloatPtr = C.POINTER(C.c_float)

def load(source, output):
    subprocess.run(['cc', '-std=c11', '-O2', '-shared', '-fPIC', '-I'+str(root/'Core'),
                    str(source), '-lm', '-pthread', '-o', str(output)], check=True)
    lib = C.CDLL(str(output))
    lib.AGAnalyzerCreate.restype = C.c_void_p
    lib.AGAnalyzerDestroy.argtypes = [C.c_void_p]
    lib.AGAnalyzerReset.argtypes = [C.c_void_p]
    lib.AGAnalyzerPushPlanar.argtypes = [C.c_void_p, FloatPtr, FloatPtr, C.c_size_t, C.c_double]
    lib.AGAnalyzerPushInterleaved.argtypes = [C.c_void_p, FloatPtr, C.c_size_t, C.c_uint, C.c_double]
    lib.AGAnalyzerCopyFrame.argtypes = [C.c_void_p, FloatPtr, FloatPtr, FloatPtr]
    return lib

with tempfile.TemporaryDirectory() as tmp:
    libs = [load(Path(sys.argv[1]).resolve(), Path(tmp)/'before.so'),
            load(root/'Core/AGAnalyzer.c', Path(tmp)/'after.so')]
    analyzers = [lib.AGAnalyzerCreate() for lib in libs]
    assert all(analyzers)
    maximum = 0.0
    snapshots = 0
    rng = random.Random(33)
    # Reuse the instances across rates to exercise cached-bin invalidation.
    for rate in [8000, 44100, 48000, 96000, 192000, 384000, 48000, 8000]:
        for kind in ['noise', 'tone', 'quiet', 'clipped', 'invalid', 'silence']:
            for block in range(20):
                count = [1, 31, 257, 1024, 2048, 4097][block % 6]
                values = []
                for i in range(count * 2):
                    if kind == 'noise': value = rng.uniform(-1, 1)
                    elif kind == 'tone': value = .45 * math.sin((i // 2 + block * 8192) * 2 * math.pi * 997 / rate)
                    elif kind == 'quiet': value = rng.uniform(-1e-5, 1e-5)
                    elif kind == 'clipped': value = rng.uniform(-4, 4)
                    elif kind == 'invalid': value = float('nan') if i % 2 else float('inf')
                    else: value = 0
                    values.append(value)
                data = (C.c_float * len(values))(*values)
                result = []
                for lib, analyzer in zip(libs, analyzers):
                    if block == 10: lib.AGAnalyzerReset(analyzer)
                    if block % 2:
                        lib.AGAnalyzerPushPlanar(analyzer, data, None, count, rate)
                    else:
                        lib.AGAnalyzerPushInterleaved(analyzer, data, count, 2, rate)
                    bands, wave, levels = (C.c_float*64)(), (C.c_float*256)(), (C.c_float*5)()
                    lib.AGAnalyzerCopyFrame(analyzer, bands, wave, levels)
                    result.append([*bands, *wave, *levels])
                assert all(math.isfinite(v) for frame in result for v in frame)
                delta = max(abs(x-y) for x, y in zip(*result))
                maximum = max(maximum, delta)
                assert delta < 1e-4, (rate, kind, block, delta)
                snapshots += 1
    for lib, analyzer in zip(libs, analyzers): lib.AGAnalyzerDestroy(analyzer)
    print(f'PASS: {snapshots} before/after snapshots; maximum absolute difference {maximum:.9g} (< 1e-4).')
