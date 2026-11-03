#!/usr/bin/env bash
# Regenerate PortionRecord's app icon via Grok Imagine (xAI images API).
# Uses XAI_API_KEY from env, this repo's .env, or ../livetranscription/.env.
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
cd "$root"

if [[ -z "${XAI_API_KEY:-}" ]]; then
  for f in .env ../livetranscription/.env; do
    if [[ -f "$f" ]]; then
      set -a
      # shellcheck disable=SC1090
      source "$f"
      set +a
      break
    fi
  done
fi
: "${XAI_API_KEY:?set XAI_API_KEY or put it in .env}"

mkdir -p Resources
python3 <<'PY'
import base64, json, os, pathlib, urllib.request

key = os.environ["XAI_API_KEY"]
prompt = (
    "Full-bleed square macOS application icon artwork, 1:1, edge-to-edge, "
    "NO rounded corners, NO outer padding, NO fake iOS icon frame, NO drop shadow, "
    "NO text, NO letters, NO watermark. "
    "For PortionRecord — a Mac app that records only a selected portion of "
    "your screen, with audio, to a video file. "
    "Fill the entire canvas with a deep charcoal / near-black field. "
    "Perfectly centered mark filling about 60% of the canvas: four thick, "
    "rounded-end corner brackets in bright warm orange (#F54E00 / ember), like "
    "camera viewfinder crop marks, framing a square region. Centered inside the "
    "brackets, a large solid bright red (#FF3B30) record dot, a perfect flat "
    "circle about 40% of the bracket span: the universal 'record' symbol, "
    "suggesting 'record this portion only'. Symmetric, bold shapes that stay "
    "legible at 32 px. Minimal, flat, premium product icon. High contrast. "
    "No monitor, no screen bezel, no purple, no gradients, no chrome 3D, no "
    "photoreal clutter. Designed so macOS can apply its own rounded-rect mask."
)
body = {
    "model": "grok-imagine-image-2.0",
    "quality": "low",
    "prompt": prompt,
    "n": 1,
    "aspect_ratio": "1:1",
    "resolution": "2k",
    "response_format": "b64_json",
}
req = urllib.request.Request(
    "https://api.x.ai/v1/images/generations",
    data=json.dumps(body).encode(),
    headers={
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    },
    method="POST",
)
with urllib.request.urlopen(req, timeout=120) as resp:
    data = json.load(resp)
item = data["data"][0]
raw = (
    base64.b64decode(item["b64_json"])
    if item.get("b64_json")
    else urllib.request.urlopen(item["url"], timeout=60).read()
)
out = pathlib.Path("Resources/icon-source.png")
out.write_bytes(raw)
print(f"wrote {out} ({out.stat().st_size} bytes)")
PY

src="Resources/icon-source.png"
setdir="Resources/AppIcon.iconset"
rm -rf "$setdir"
mkdir "$setdir"
for size in 16 32 128 256 512; do
  retina=$((size * 2))
  sips -z "$size" "$size" "$src" --out "$setdir/icon_${size}x${size}.png" >/dev/null
  sips -z "$retina" "$retina" "$src" --out "$setdir/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$setdir" -o Resources/AppIcon.icns
rm -rf "$setdir"
echo "wrote Resources/AppIcon.icns — re-run ./build.sh to install"
