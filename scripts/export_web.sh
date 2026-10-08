#!/usr/bin/env bash
# Builds the single-threaded web export into build/web/ and optionally serves it.
# Usage: scripts/export_web.sh [--serve]   (then open http://localhost:8060)
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
echo "exported build/web/index.html"
if [[ "${1:-}" == "--serve" ]]; then
	# Single-threaded export needs no COOP/COEP headers, so a plain static server works.
	python3 -m http.server 8060 --bind 127.0.0.1 --directory build/web
fi
