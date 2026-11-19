"""Rebuild the six featured Athan recordings from checksum-pinned sources.

Install imageio-ffmpeg==0.8.1, then run this script. --source-dir optionally
reuses downloaded originals named <id>.mp3 (or madinah.ogg). This command is
build-time tooling only: the app never downloads these recordings at prayer time.
"""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import urllib.request
import wave

import imageio_ffmpeg


ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / "asset"
RAW = ROOT / "android/app/src/main/res/raw"
MANIFEST = Path(__file__).with_name("athan_audio_manifest.json")


def run(ffmpeg, *arguments):
    return subprocess.run(
        [ffmpeg, "-nostdin", "-hide_banner", "-v", "error", *arguments],
        check=True,
        capture_output=True,
    ).stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path)
    args = parser.parse_args()
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    report = []
    with tempfile.TemporaryDirectory(prefix="athan-featured-") as temp:
        for record in manifest["recordings"]:
            name = record["id"]
            extension = ".ogg" if name == "madinah" else ".mp3"
            source = Path(temp) / (name + extension)
            if args.source_dir:
                data = (args.source_dir / source.name).read_bytes()
            else:
                request = urllib.request.Request(
                    record["url"],
                    headers={"User-Agent": "AthanApp/2.1 (https://github.com/wlaa41/flutterAthanApp)"},
                )
                with urllib.request.urlopen(request, timeout=60) as response:
                    data = response.read()
            if hashlib.sha256(data).hexdigest() != record["sha256"]:
                raise RuntimeError(f"Source checksum changed for {name}; review before replacing it.")
            source.write_bytes(data)

            # Decode the complete source, so damaged/truncated media fails here.
            decoded = run(ffmpeg, "-i", str(source), "-f", "s16le", "-ac", "1", "-ar", "8000", "-")
            duration = len(decoded) / 16000
            if not 30 < duration < 600:
                raise RuntimeError(f"Unexpected full-recording duration for {name}: {duration}")

            full = ASSET / (name + ".mp3")
            run(ffmpeg, "-y", "-i", str(source), "-vn", "-map_metadata", "-1",
                "-ac", "1", "-ar", "44100", "-b:a", "96k", str(full))
            shutil.copyfile(full, RAW / full.name)
            excerpt = ASSET / (name + "_short.wav")
            run(ffmpeg, "-y", "-i", str(source), "-t", "28", "-vn", "-map_metadata", "-1",
                "-af", "afade=t=out:st=27:d=1", "-ac", "1", "-ar", "22050",
                "-c:a", "pcm_s16le", str(excerpt))
            with wave.open(str(excerpt), "rb") as sound:
                seconds = sound.getnframes() / sound.getframerate()
                if sound.getsampwidth() != 2 or sound.getnchannels() != 1 or not 0 < seconds < 30:
                    raise RuntimeError(f"Invalid iOS notification excerpt: {excerpt}")
            # Also decode the complete prepared MP3, not only its header.
            prepared = run(ffmpeg, "-i", str(full), "-f", "s16le", "-ac", "1", "-ar", "8000", "-")
            full_seconds = len(prepared) / 16000
            if abs(full_seconds - duration) > .1:
                raise RuntimeError(f"Conversion changed recording length: {name}")
            report.append({
                "id": name,
                "duration_seconds": round(full_seconds, 3),
                "mp3_bytes": full.stat().st_size,
                "mp3_sha256": hashlib.sha256(full.read_bytes()).hexdigest(),
                "ios_seconds": seconds,
                "ios_sha256": hashlib.sha256(excerpt.read_bytes()).hexdigest(),
                "android_copy_matches": full.read_bytes() == (RAW / full.name).read_bytes(),
            })
            print(f"{name}: {full_seconds:.1f}s MP3, {seconds:.0f}s PCM WAV, Android copy verified")
    Path(__file__).with_name("athan_audio_verification.json").write_text(
        json.dumps({"encoder": imageio_ffmpeg.get_ffmpeg_version(), "recordings": report}, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
