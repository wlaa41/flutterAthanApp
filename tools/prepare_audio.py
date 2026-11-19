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

rate = 22050
for name, seconds, notes in [
    ('beep', .32, [(0,.25,660)]),
    ('double_beep', .65, [(0,.2,660),(.35,.2,660)]),
    ('chime', 1.2, [(0,1.1,523.25),(.18,.9,783.99)])
]:
    samples = []
    for i in range(int(rate*seconds)):
        t = i/rate
        value = 0
        for start, length, hz in notes:
            local = t-start
            if 0 <= local < length:
                envelope = min(1,local/.015,(length-local)/.04)
                if name == 'chime': envelope *= math.exp(-3*local)
                value += .15*envelope*math.sin(2*math.pi*hz*local)
        samples.append(struct.pack('<h', int(max(-1,min(1,value))*32767)))
    path = asset/(name+'.wav')
    with wave.open(str(path),'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(rate)
        f.writeframes(b''.join(samples))
    shutil.copyfile(path, raw/path.name)
print('Created MP3 recitations, 28-second iOS excerpts and three original quiet tones.')
