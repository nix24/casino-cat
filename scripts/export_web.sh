#!/usr/bin/env bash
# Builds the single-threaded web export into build/web/, prints its size against the D48 budget,
# and optionally zips it for the itch.io upload or serves it.
# Usage: scripts/export_web.sh [--zip] [--serve]
#   --zip    also write build/casino-cat-web.zip with index.html at the zip root (zip runs before serve)
#   --serve  serve build/web at http://127.0.0.1:8060 (blocks; open http://localhost:8060)
# Exits 2 on an unknown flag. An over-budget size is reported but does not fail the script (T044 owns the gate).
set -euo pipefail
cd "$(dirname "$0")/.."

readonly WEB_BUDGET_BYTES=50000000
readonly PCK_BUDGET_BYTES=10000000
readonly ZIP_PATH="build/casino-cat-web.zip"

zip_requested=false
serve_requested=false
for arg in "$@"; do
	case "$arg" in
		--zip) zip_requested=true ;;
		--serve) serve_requested=true ;;
		*)
			echo "usage: scripts/export_web.sh [--zip] [--serve]" >&2
			exit 2
			;;
	esac
done

# Start from an empty build/web so no file from an older export ships. build/.gdignore keeps the
# editor from importing the exported PNGs (that is where stray *.import files came from).
rm -rf build/web
mkdir -p build/web
touch build/.gdignore
godot --headless --path . --export-release "Web" build/web/index.html
echo "exported build/web/index.html"

web_bytes="$(du -sb build/web | cut -f1)"
pck_bytes="$(stat -c %s build/web/index.pck)"
web_mb="$(awk -v bytes="$web_bytes" 'BEGIN { printf "%.1f", bytes / 1000000 }')"
web_over=""
pck_over=""
if ((web_bytes > WEB_BUDGET_BYTES)); then web_over=" OVER BUDGET (D48)"; fi
if ((pck_bytes > PCK_BUDGET_BYTES)); then pck_over=" OVER BUDGET (D48)"; fi
echo "web build: ${web_bytes} bytes (${web_mb} MB), budget ${WEB_BUDGET_BYTES}${web_over}"
echo "index.pck: ${pck_bytes} bytes, budget ${PCK_BUDGET_BYTES}${pck_over}"

if [[ "$zip_requested" == true ]]; then
	# Zip from inside build/web/ so that index.html sits at the zip root, not under build/web/.
	zip_abs="$PWD/$ZIP_PATH"
	rm -f "$zip_abs"
	if command -v zip >/dev/null; then
		(cd build/web && zip -qr "$zip_abs" .)
	else
		(cd build/web && python3 -m zipfile -c "$zip_abs" ./*)
	fi
	echo "zipped ${ZIP_PATH} ($(stat -c %s "$ZIP_PATH") bytes)"
fi

if [[ "$serve_requested" == true ]]; then
	# Single-threaded export needs no COOP/COEP headers, so a plain static server works.
	python3 -m http.server 8060 --bind 127.0.0.1 --directory build/web
fi
