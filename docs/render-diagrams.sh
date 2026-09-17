#!/usr/bin/env bash
# Render the Mermaid diagram in each README to docs/diagrams/<name>.png.
#
# The GitHub mobile app has no Mermaid renderer, so every page embeds a
# pre-rendered PNG and keeps the Mermaid source in a collapsed <details> block.
# That block is the single source of truth — edit it, then re-run this script.
#
# Needs node; pulls mermaid-cli via npx on first run.
set -euo pipefail

cd "$(dirname "$0")/.."
out=docs/diagrams
mkdir -p "$out"

# 2× the design width: correct size on desktop, sharp on a phone.
SCALE=2

for readme in README.md */README.md; do
  case "$readme" in
    README.md) name=overview ;;
    *)         name="${readme%/README.md}" ;;
  esac

  tmp=$(mktemp --suffix=.mmd)
  awk '/^```mermaid$/{f=1;next} /^```$/{f=0} f' "$readme" > "$tmp"

  if [ ! -s "$tmp" ]; then
    rm -f "$tmp"
    continue
  fi

  echo "rendering $readme -> $out/$name.png"
  npx --yes @mermaid-js/mermaid-cli \
    -i "$tmp" -o "$out/$name.png" -s "$SCALE" -b white >/dev/null
  rm -f "$tmp"
done

echo "done"
