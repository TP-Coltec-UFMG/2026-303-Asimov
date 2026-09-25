"""Create the small, original sound cues used by the game's ambient layer.

Run with Python and NumPy from this directory. The fixed seed makes the WAVs
reproducible; no third-party recordings or licences are required.
"""

from pathlib import Path
import wave

import numpy as np


RATE = 22050
OUT = Path(__file__).resolve().parent
rng = np.random.default_rng(303)


def time(seconds):
    return np.arange(round(seconds * RATE), dtype=np.float64) / RATE


def lowpass(data, width):
    kernel = np.ones(width) / width
    return np.convolve(data, kernel, mode="same")


def save(name, samples, peak=0.60):
    samples = np.asarray(samples, dtype=np.float64)
    samples -= np.mean(samples)
    maximum = np.max(np.abs(samples))
    if maximum:
        samples *= min(1.0, peak / maximum)
    with wave.open(str(OUT / name), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes((np.clip(samples, -1, 1) * 32767).astype("<i2").tobytes())


def smooth_envelope(t, attack, decay):
    return np.minimum(1, t / attack) * np.exp(-t / decay)


for surface in ("tile", "metal", "debris"):
    for variant in range(3):
        t = time(0.23)
        noise = rng.standard_normal(t.size)
        thump = np.sin(2 * np.pi * (82 + 9 * variant) * t) * np.exp(-t * 25)
        if surface == "tile":
            sound = 0.48 * thump + 0.26 * lowpass(noise, 10) * np.exp(-t * 31)
            sound += 0.14 * noise * np.exp(-((t - .055) / .026) ** 2)
        elif surface == "metal":
            ring = np.sin(2 * np.pi * (480 + variant * 58) * t)
            sound = 0.30 * thump + 0.25 * ring * np.exp(-t * 15)
            sound += 0.15 * noise * np.exp(-t * 45)
        else:
            crackle = np.zeros_like(t)
            for offset in (.015, .040, .067, .091):
                crackle += noise * np.exp(-((t - offset) / .009) ** 2)
            sound = 0.30 * thump + 0.28 * crackle
        save(f"step_{surface}_{variant + 1}.wav", sound * .80)

t = time(.20)
save("grab.wav", .45 * np.sin(2*np.pi*190*t)*np.exp(-t*24) + .3*rng.standard_normal(t.size)*np.exp(-t*36))
t = time(.30)
save("release.wav", .5*np.sin(2*np.pi*110*t)*np.exp(-t*19) + .18*rng.standard_normal(t.size)*np.exp(-t*21))
t = time(.42)
scrape = lowpass(rng.standard_normal(t.size), 6) * smooth_envelope(t, .025, .25)
save("scrape.wav", scrape, .38)

t = time(.48)
swipe = lowpass(rng.standard_normal(t.size), 14) * np.minimum(1, t/.04) * np.exp(-t*5)
swipe += .18*np.sin(2*np.pi*(700*t+600*t*t))*np.exp(-t*6)
save("card_swipe.wav", swipe, .38)
t = time(.11)
save("terminal_key.wav", .3*np.sin(2*np.pi*970*t)*np.exp(-t*39) + .13*rng.standard_normal(t.size)*np.exp(-t*67), .36)
t = time(.32)
save("breaker.wav", .42*np.sin(2*np.pi*125*t)*np.exp(-t*24) + .33*rng.standard_normal(t.size)*np.exp(-((t-.04)/.025)**2), .62)
t = time(.34)
save("access_granted.wav", (.26*np.sin(2*np.pi*680*t)*np.exp(-((t-.07)/.07)**2)
                            +.24*np.sin(2*np.pi*920*t)*np.exp(-((t-.20)/.08)**2)), .42)
t = time(.30)
save("access_denied.wav", .28*np.sin(2*np.pi*360*t)*np.exp(-((t-.06)/.07)**2)
                           +.22*np.sin(2*np.pi*290*t)*np.exp(-((t-.18)/.07)**2), .40)
t = time(.42)
save("door_latch.wav", .35*np.sin(2*np.pi*140*t)*np.exp(-t*16)
                         +.17*rng.standard_normal(t.size)*np.exp(-((t-.07)/.024)**2), .45)

t = time(.65)
drip = np.sin(2*np.pi*(1050*t-850*t*t)) * np.exp(-t*28)
drip += .25*np.sin(2*np.pi*620*t)*np.exp(-((t-.13)/.065)**2)
save("hall_drip.wav", drip, .42)
t = time(2.0)
creak = np.sin(2*np.pi*(145*t + 34*t*t + 8*np.sin(2*np.pi*.8*t)))
creak += .27*lowpass(rng.standard_normal(t.size), 30)
save("hall_metal_creak.wav", creak * np.sin(np.pi*t/2)**2 * .32, .48)

for name, base, wind in (("hall_air.wav", 70, .12), ("server_hum.wav", 95, .07), ("cooling_air.wav", 58, .22)):
    t = time(8.0)
    phases = rng.uniform(0, 2*np.pi, 4)
    hum = (.23*np.sin(2*np.pi*base*t+phases[0])
           +.12*np.sin(2*np.pi*base*2*t+phases[1])
           +.055*np.sin(2*np.pi*base*3*t+phases[2]))
    air = lowpass(rng.standard_normal(t.size), 42) * wind
    samples = hum + air
    # Make the ambience wrap without a click when Godot loops the WAV.
    fade = round(.12 * RATE)
    mix = np.linspace(0, 1, fade)
    samples[-fade:] = samples[-fade:] * (1-mix) + samples[:fade][::-1] * mix
    save(name, samples, .28)
