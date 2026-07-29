#!/usr/bin/env python3
"""Print a compact onset/tempo map for the PV's rendered BGM."""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

import numpy as np
from scipy.ndimage import gaussian_filter1d
from scipy.signal import find_peaks


def decode_mono(path: Path, sample_rate: int) -> np.ndarray:
    result = subprocess.run(
        [
            "ffmpeg",
            "-v",
            "error",
            "-i",
            str(path),
            "-ac",
            "1",
            "-ar",
            str(sample_rate),
            "-f",
            "f32le",
            "pipe:1",
        ],
        check=True,
        capture_output=True,
    )
    return np.frombuffer(result.stdout, dtype="<f4")


def onset_envelope(samples: np.ndarray, sample_rate: int) -> tuple[np.ndarray, np.ndarray]:
    frame_size = 2048
    hop_size = 256
    frame_count = 1 + max(0, (len(samples) - frame_size) // hop_size)
    if frame_count < 2:
        raise ValueError("Audio is too short for beat analysis.")

    shape = (frame_count, frame_size)
    strides = (samples.strides[0] * hop_size, samples.strides[0])
    frames = np.lib.stride_tricks.as_strided(samples, shape=shape, strides=strides)
    spectra = np.log1p(np.abs(np.fft.rfft(frames * np.hanning(frame_size), axis=1)))
    flux = np.maximum(0.0, np.diff(spectra, axis=0)).sum(axis=1)
    envelope = np.concatenate(([0.0], flux))
    envelope = gaussian_filter1d(envelope, sigma=1.0)
    envelope -= np.median(envelope)
    envelope = np.maximum(envelope, 0.0)
    peak = float(envelope.max())
    if peak > 0:
        envelope /= peak
    times = np.arange(frame_count) * hop_size / sample_rate
    return times, envelope


def tempo_candidates(envelope: np.ndarray, sample_rate: int, count: int = 8) -> list[tuple[float, float]]:
    hop_size = 256
    centered = envelope - envelope.mean()
    correlation = np.correlate(centered, centered, mode="full")[len(centered) - 1 :]
    min_bpm, max_bpm = 70.0, 190.0
    min_lag = max(1, int(round(60.0 * sample_rate / (max_bpm * hop_size))))
    max_lag = int(round(60.0 * sample_rate / (min_bpm * hop_size)))
    search = correlation[min_lag : max_lag + 1]
    peaks, _ = find_peaks(search, distance=2)
    if not len(peaks):
        peaks = np.arange(len(search))
    ranked = peaks[np.argsort(search[peaks])[::-1]]
    candidates: list[tuple[float, float]] = []
    for peak_index in ranked:
        lag = int(peak_index + min_lag)
        bpm = 60.0 * sample_rate / (lag * hop_size)
        score = float(search[peak_index] / max(correlation[0], 1e-9))
        if all(abs(bpm - existing[0]) > 1.0 for existing in candidates):
            candidates.append((bpm, score))
        if len(candidates) >= count:
            break
    return candidates


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("audio", type=Path)
    parser.add_argument("--bpm", type=float)
    args = parser.parse_args()

    sample_rate = 22050
    samples = decode_mono(args.audio.resolve(), sample_rate)
    times, envelope = onset_envelope(samples, sample_rate)
    candidates = tempo_candidates(envelope, sample_rate)
    bpm = args.bpm or candidates[0][0]
    period = 60.0 / bpm

    frame_step = times[1] - times[0]
    phase_count = max(2, int(round(period / frame_step)))
    phase_scores = np.array(
        [envelope[index::phase_count].sum() for index in range(phase_count)]
    )
    phase = float(times[int(np.argmax(phase_scores))])

    peak_indices, properties = find_peaks(
        envelope,
        distance=max(1, int(round(0.18 / frame_step))),
        prominence=0.08,
    )
    ranked_peaks = peak_indices[np.argsort(envelope[peak_indices])[::-1]]
    strong_times = sorted(float(times[index]) for index in ranked_peaks[:40])

    print("Tempo candidates:")
    for candidate_bpm, score in candidates:
        print(f"  {candidate_bpm:7.3f} BPM  score={score:.4f}")
    print(f"Selected grid: {bpm:.3f} BPM, period={period:.4f}s, phase={phase:.4f}s")
    print("Strong onsets:")
    print("  " + ", ".join(f"{time:.3f}" for time in strong_times))
    print("Four-beat bar starts:")
    bar = phase
    while bar - 4 * period >= 0:
        bar -= 4 * period
    bars = []
    while bar <= times[-1]:
        if bar >= 0:
            bars.append(bar)
        bar += 4 * period
    print("  " + ", ".join(f"{time:.3f}" for time in bars))


if __name__ == "__main__":
    main()
