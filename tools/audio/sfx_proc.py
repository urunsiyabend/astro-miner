# Trim, fade, loudness-match and resample generated SFX takes -> 44.1 kHz mono 16-bit WAV.
#   python3 tools/audio/sfx_proc.py <dir of raw takes> <out dir>   (needs ffmpeg, numpy)
import numpy as np, wave, sys, glob, os, subprocess
SR = 44100
TARGET_RMS = -18.0   # active-region RMS each take is brought to (peak capped at -1 dBFS)
def load(p):
    out = subprocess.run(["ffmpeg", "-v", "error", "-i", p, "-ac", "1", "-ar", str(SR), "-f", "s16le", "-"], capture_output=True).stdout
    return np.frombuffer(out, dtype=np.int16).astype(np.float32) / 32768
def save(p, x):
    w = wave.open(p, "wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes()); w.close()
def process(src, dst, tail_db=-42.0):
    x = load(src); pk = np.abs(x).max() + 1e-9
    hop = int(SR * 0.005)
    env = np.array([np.abs(x[i:i + hop]).max() for i in range(0, len(x), hop)])
    db = 20 * np.log10(env / pk + 1e-9)
    act = np.where(db > -30)[0]
    a = max(0, act[0] * hop - int(0.003 * SR))
    b = min(len(x), (np.where(db > tail_db)[0][-1] + 1) * hop)
    y = x[a:b].copy()
    fi = int(0.003 * SR); y[:fi] *= np.linspace(0, 1, fi)
    fo = max(int(0.03 * SR), int(len(y) * 0.2)); fo = min(fo, len(y))
    y[-fo:] *= np.linspace(1, 0, fo) ** 1.5
    rms = 20 * np.log10(np.sqrt(np.mean(y ** 2)) + 1e-9)
    peak = 20 * np.log10(np.abs(y).max() + 1e-9)
    g = min(TARGET_RMS - rms, -1.0 - peak)
    y *= 10 ** (g / 20)
    save(dst, y)
    return len(y) / SR, g
if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    for p in sorted(glob.glob(src + "/*.wav")):
        n = os.path.basename(p)
        d, g = process(p, os.path.join(dst, n))
        print(f"{n:16s} {d:5.2f}s gain {g:+5.1f} dB")
