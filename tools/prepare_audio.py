import math
import hashlib
import shutil
import struct
import subprocess
import tempfile
import urllib.request
import wave
from pathlib import Path
import imageio_ffmpeg

root = Path(__file__).resolve().parents[1]
asset = root / 'asset'
raw = root / 'android/app/src/main/res/raw'
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
sources = {
    'beautiful_adhan': ('https://upload.wikimedia.org/wikipedia/commons/b/b0/Beautiful_adhan.ogg', 'a1fa4fd942401922c5c3301816384aae86956522'),
    'iqama': ('https://upload.wikimedia.org/wikipedia/commons/0/00/Iqamah.ogg', '563ec4bbc12c8a67ddb5c96adce597fdb526f988'),
}
with tempfile.TemporaryDirectory(prefix='athan-audio-') as temporary:
    for name, (url, expected) in sources.items():
        request = urllib.request.Request(url, headers={'User-Agent': 'AthanApp/1.0 (https://github.com/wlaa41/flutterAthanApp)'})
        with urllib.request.urlopen(request, timeout=30) as response:
            data = response.read()
        if hashlib.sha1(data).hexdigest() != expected:
            raise RuntimeError(f'Source checksum changed for {name}; review license and audio before updating.')
        source = Path(temporary)/(name+'.ogg')
        source.write_bytes(data)
        subprocess.run([ffmpeg, '-y', '-i', str(source), '-vn', '-ac', '1', '-ar', '44100', '-b:a', '96k', str(asset / (name + '.mp3'))], check=True, capture_output=True)
        shutil.copyfile(asset / (name + '.mp3'), raw / (name + '.mp3'))
        subprocess.run([ffmpeg, '-y', '-i', str(source), '-t', '28', '-af', 'afade=t=out:st=27:d=1', '-ac', '1', '-ar', '22050', '-c:a', 'pcm_s16le', str(asset / (name + '_short.wav'))], check=True, capture_output=True)

# The reminder tones and their five loudness levels come from make_tones.py.
subprocess.run(['python3', str(root / 'tools' / 'make_tones.py')], check=True)
print('Created MP3 recitations, 28-second iOS excerpts and the reminder tones.')
