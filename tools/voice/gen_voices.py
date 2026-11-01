"""Generate character voice lines with ElevenLabs (eleven_v3, Azerbaijani).

Reads data/voice_lines.json and the API key from _setup/elevenlabs_key.txt
(never printed). Raw mp3 goes to tools/voice/out/raw (git-ignored, reused so a
rerun spends no characters); the game file is a pitched, loudness-normalised
mono OGG at assets/voice/<racer>/<category>_<n>.ogg.

Usage: python tools/voice/gen_voices.py [--only=yaska] [--dry]
"""
import json
import os
import subprocess
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(ROOT, "tools", "voice", "out", "raw")
OUT = os.path.join(ROOT, "assets", "voice")
API = "https://api.elevenlabs.io/v1"


def api_key() -> str:
	with open(os.path.join(ROOT, "_setup", "elevenlabs_key.txt"), encoding="utf-8-sig") as f:
		for line in f:
			if line.strip().startswith("ELEVENLABS_API_KEY="):
				return line.split("=", 1)[1].strip()
	raise SystemExit("no key")


def request(path: str, key: str, body=None) -> bytes:
	req = urllib.request.Request(API + path, data=None if body is None else json.dumps(body).encode("utf-8"))
	req.add_header("xi-api-key", key)
	if body is not None:
		req.add_header("Content-Type", "application/json")
		req.add_header("Accept", "audio/mpeg")
	with urllib.request.urlopen(req, timeout=120) as r:
		return r.read()


def usage(key: str) -> str:
	sub = json.loads(request("/user/subscription", key))
	return "%d/%d" % (sub.get("character_count", 0), sub.get("character_limit", 0))


def tts(key: str, voice_id: str, text: str) -> bytes:
	return request("/text-to-speech/%s?output_format=mp3_44100_128" % voice_id, key, {
		"text": text,
		"model_id": "eleven_v3",
		"language_code": "az",
		"voice_settings": {"stability": 0.4, "similarity_boost": 0.75},
	})


def encode(src: str, dst: str, pitch: float) -> None:
	af = "asetrate=44100*%.3f,aresample=44100,atempo=%.4f,silenceremove=start_periods=1:start_threshold=-45dB," \
		"areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse,loudnorm=I=-16:TP=-1.5" % (pitch, 1.0 / pitch)
	subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-af", af, "-ac", "1", "-ar", "44100",
		"-c:a", "libvorbis", "-q:a", "4", dst], check=True)


def main() -> None:
	only = ""
	dry = "--dry" in sys.argv
	for a in sys.argv[1:]:
		if a.startswith("--only="):
			only = a.split("=", 1)[1]
	data = json.load(open(os.path.join(ROOT, "data", "voice_lines.json"), encoding="utf-8"))
	key = api_key()
	os.makedirs(RAW, exist_ok=True)
	print("usage before", usage(key))
	made = spent = 0
	for racer, cats in data["lines"].items():
		if only and racer != only:
			continue
		voice = data["voices"][racer]
		os.makedirs(os.path.join(OUT, racer), exist_ok=True)
		for cat, lines in cats.items():
			for i, text in enumerate(lines):
				name = "%s_%d" % (cat, i)
				raw = os.path.join(RAW, "%s_%s.mp3" % (racer, name))
				if not os.path.exists(raw):
					if dry:
						print("would make", racer, name, len(text))
						continue
					with open(raw, "wb") as f:
						f.write(tts(key, voice["voice_id"], text))
					spent += len(text)
				dst = os.path.join(OUT, racer, name + ".ogg")
				encode(raw, dst, float(voice["pitch"]))
				made += 1
	print("files", made, "chars sent", spent)
	print("usage after", usage(key))


if __name__ == "__main__":
	main()
