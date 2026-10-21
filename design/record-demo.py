#!/usr/bin/env python3
"""Record the real core-loop UI test, preserving native motion and reading holds.

Build before capture; trim only at timestamped test cues. Raw video and logs
stay in ignored .captures/demo/ for inspection. Existing published media is
replaced only after the test, encoding and cadence checks all pass.
"""
import json
import os
import pathlib
import re
import select
import signal
import subprocess
import sys
import time

from PIL import Image, ImageChops, ImageStat

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEVICE = sys.argv[1] if len(sys.argv) > 1 else "iPhone 17e"
WORK = ROOT / ".captures" / "demo"
DERIVED = ROOT / ".build" / "demo"
BEATS = ["BEGIN", "OPEN", "RECEIPT", "SCROLL", "FOOTER", "TEAR", "RETURN", "END"]


def run(*args, **kwargs):
    return subprocess.run(args, cwd=ROOT, check=True, **kwargs)


def probe(path):
    return json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_streams", "-show_format", "-of", "json", str(path),
    ]))


def main():
    WORK.mkdir(parents=True, exist_ok=True)
    run("xcodegen", "generate")
    run("xcrun", "simctl", "bootstatus", DEVICE, "-b")
    run("xcrun", "simctl", "ui", DEVICE, "appearance", "light")
    base = ["xcodebuild", "-project", "Milemark.xcodeproj", "-scheme", "Milemark",
            "-destination", f"platform=iOS Simulator,name={DEVICE}",
            "-derivedDataPath", str(DERIVED), "-parallel-testing-enabled", "NO"]
    print("Building the app and test runner before recording…", flush=True)
    with (WORK / "build.log").open("w") as log:
        subprocess.run(base + ["build-for-testing"], cwd=ROOT, stdout=log,
                       stderr=subprocess.STDOUT, check=True, timeout=600)

    run("xcrun", "simctl", "status_bar", DEVICE, "override", "--time", "9:41",
        "--dataNetwork", "wifi", "--wifiMode", "active", "--wifiBars", "3",
        "--batteryState", "charged", "--batteryLevel", "100")
    raw = WORK / "raw.mp4"
    recorder = subprocess.Popen([
        "xcrun", "simctl", "io", DEVICE, "recordVideo", "--codec=h264", "--force", str(raw),
    ], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    recording_epoch = None
    try:
        deadline = time.monotonic() + 30
        with (WORK / "recorder.log").open("w") as log:
            while time.monotonic() < deadline:
                if recorder.poll() is not None:
                    raise RuntimeError("Simulator recorder exited before its first frame")
                ready, _, _ = select.select([recorder.stderr], [], [], 0.2)
                if not ready:
                    continue
                line = recorder.stderr.readline()
                log.write(line)
                if "Recording started" in line:
                    recording_epoch = time.time()
                    break
        if recording_epoch is None:
            raise RuntimeError("Simulator recorder did not start within 30 seconds")
        print("Recording one continuous take…", flush=True)
        with (WORK / "test.log").open("w") as log:
            subprocess.run(base + ["test-without-building",
                "-only-testing:MilemarkUITests/CoreLoopTests/testTheCoreLoop"],
                cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
    finally:
        if recorder.poll() is None:
            recorder.send_signal(signal.SIGINT)
            try:
                recorder.wait(timeout=30)
            except subprocess.TimeoutExpired:
                recorder.kill()
                recorder.wait()
                raise RuntimeError("Simulator recorder could not finalize the video")
        recorder.stderr.close()
        run("xcrun", "simctl", "status_bar", DEVICE, "clear")
    if recorder.returncode != 0:
        raise RuntimeError(f"Simulator recording failed: {recorder.returncode}")

    text = (WORK / "test.log").read_text()
    matches = re.findall(r"MILEMARK_DEMO_(\w+) (\d+\.\d+)", text)
    if [name for name, _ in matches] != BEATS:
        raise RuntimeError("Missing or out-of-order showcase cues; keeping previous media")
    beats = {name: float(timestamp) for name, timestamp in matches}
    start = beats["BEGIN"] - recording_epoch
    duration = beats["END"] - beats["BEGIN"]
    if start < 0 or not 24 <= duration <= 36:
        raise RuntimeError(f"Unexpected showcase timing: start={start:.2f}, duration={duration:.2f}")
    for begin, end, minimum in [("BEGIN", "OPEN", 3), ("RECEIPT", "SCROLL", 8),
                                 ("FOOTER", "TEAR", 4), ("RETURN", "END", 4)]:
        if beats[end] - beats[begin] < minimum:
            raise RuntimeError(f"The {begin.lower()} reading hold was shortened")

    # simctl's H.264 stream can have duplicate presentation timestamps and
    # misleading decode timestamps after a still hold. FFmpeg's default
    # best-effort fallback then jumps BACKWARDS, skipping holds/transitions.
    # Ignore DTS: the original presentation timestamps retain real elapsed time.
    timeline = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-fflags", "+igndts", "-show_frames",
        "-show_entries", "frame=best_effort_timestamp_time", "-of", "json", str(raw),
    ]))
    timestamps = [float(frame["best_effort_timestamp_time"]) for frame in timeline["frames"]]
    if any(b < a for a, b in zip(timestamps, timestamps[1:])):
        raise RuntimeError("Source timestamps run backwards even after ignoring DTS")
    for begin, end in [("OPEN", "RECEIPT"), ("TEAR", "RETURN")]:
        a, b = beats[begin] - recording_epoch, beats[end] - recording_epoch
        if sum(a <= timestamp <= b for timestamp in timestamps) < 15:
            raise RuntimeError(f"Not enough native frames in the {begin.lower()} transition")

    movie = WORK / "milemark-demo.mp4"
    gif = WORK / "milemark-demo.gif"
    # Decode/re-encode from the raw source into a DIFFERENT file. No in-place
    # ffmpeg input/output, fixed startup offsets, time stretching or internal cuts.
    run("ffmpeg", "-y", "-v", "error", "-fflags", "+igndts", "-i", str(raw), "-ss", f"{start:.6f}",
        "-t", f"{duration:.6f}", "-vf", "fps=60,scale=780:-2:flags=lanczos",
        "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p",
        "-movflags", "+faststart", "-an", str(movie))
    run(sys.executable, "design/frame-demo.py", str(movie), str(gif))
    info = probe(movie)
    stream = info["streams"][0]
    frames = int(stream["nb_frames"])
    movie_duration = float(stream["duration"])
    if abs(movie_duration - duration) > 0.1 or abs(frames - duration * 60) > 2:
        raise RuntimeError("MP4 duration/cadence check failed; keeping previous media")
    gif_duration = float(probe(gif)["format"]["duration"])
    if abs(gif_duration - movie_duration) > 0.1:
        raise RuntimeError("GIF duration differs from the MP4; keeping previous media")

    # Both ends must be the archive, not the simulator home screen or a
    # receipt left open after a failed pull. This also catches misaligned trims.
    for name, position in [("first", 0.5), ("last", movie_duration - 0.5)]:
        run("ffmpeg", "-y", "-v", "error", "-ss", str(position), "-i", str(movie),
            "-frames:v", "1", "-vf", "scale=96:-1", str(WORK / f"{name}.png"))
    with Image.open(WORK / "first.png") as first, Image.open(WORK / "last.png") as last:
        difference = ImageStat.Stat(ImageChops.difference(first.convert("RGB"), last.convert("RGB")))
        bookend_difference = sum(difference.mean) / (3 * 255)
    if bookend_difference > 0.035:
        raise RuntimeError("Opening/closing archive frames do not match; inspect the trim")

    report = {"duration": movie_duration, "frames": frames, "fps": 60,
              "gif_duration": gif_duration, "trim_start": start,
              "recording_epoch": recording_epoch,
              "bookend_difference": bookend_difference,
              "beats": {name: round(value - beats["BEGIN"], 3) for name, value in beats.items()}}
    (WORK / "timing.json").write_text(json.dumps(report, indent=2) + "\n")
    for source in [movie, gif]:
        target = ROOT / "design" / "demo" / source.name
        target.parent.mkdir(parents=True, exist_ok=True)
        # Copy to a sibling first so the published file replacement is atomic.
        temporary = target.with_suffix(target.suffix + ".tmp")
        temporary.write_bytes(source.read_bytes())
        os.replace(temporary, target)
    print(json.dumps(report, indent=2))
    print("Published MP4 and GIF. Inspect .captures/demo/ for the raw take and logs.")


if __name__ == "__main__":
    try:
        main()
    except (subprocess.SubprocessError, RuntimeError) as error:
        sys.exit(f"Recording failed: {error}. See .captures/demo/ for logs.")
