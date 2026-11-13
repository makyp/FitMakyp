"""Genera los sonidos del cronómetro (WAV) sin depender de bancos de sonido externos.

Uso: python -I tool/make_sounds.py   (desde la carpeta app)
"""
import math
import struct
import wave

RATE = 44100


def tone(freqs, dur, vol=0.5, attack=0.005, decay=6.0):
    out = []
    for i in range(int(RATE * dur)):
        t = i / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t)
        s = sum(math.sin(2 * math.pi * f * t) + 0.25 * math.sin(4 * math.pi * f * t) for f in freqs) / len(freqs)
        out.append(vol * env * s / 1.25)
    return out


def save(name, samples):
    with wave.open(f'assets/sounds/{name}.wav', 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s)) * 32767)) for s in samples))


# "tic" suave para 3, 2, 1
save('tick', tone([880], 0.14, vol=0.45, decay=28))
# campanita ascendente al terminar el descanso
chime = tone([784], 0.18, vol=0.5, decay=10) + tone([1046.5], 0.18, vol=0.5, decay=10) + tone([1318.5, 1568], 0.7, vol=0.55, decay=4.5)
save('rest_end', chime)
print('ok')
