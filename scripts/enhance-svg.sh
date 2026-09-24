#!/usr/bin/env bash
# Injects the flow-animation CSS into rendered SVGs. A project's ./diagrams/animations.css wins
# over the plugin's copy, so a repo can restyle its animations without forking the plugin.
#
# d2 sizes each dashed connection's gap to fit its length and writes the pattern inline, so no
# shared keyframe offset matches every period, and a mismatch shows as a jump once per loop. Each
# dashed connection therefore gets keyframes that travel exactly its own period, at 9px/s: slower
# than the 12px/s solid flow, so async edges still read as async.
#
# Usage: enhance-svg.sh FILE.svg...

set -euo pipefail

marker="D2 Diagram Animations"
plugin_root="$(cd "$(dirname "$0")/.." && pwd)"
css_file="./diagrams/animations.css"
[ -f "$css_file" ] || css_file="$plugin_root/assets/animations.css"

if [ $# -eq 0 ]; then
  echo "usage: enhance-svg.sh FILE.svg..." >&2
  exit 2
fi

CSS=$(cat "$css_file")
export CSS
for svg in "$@"; do
  if grep -q "$marker" "$svg"; then
    continue
  fi
  perl -0777 -i -pe '
    my %period;
    s{<path\b[^>]*\bmarker-end="[^"]*"[^>]*>}{
      my $tag = $&;
      if ($tag =~ /stroke-dasharray:\s*([\d.]+)[,\s]+([\d.]+)/) {
        my $p = $1 + $2;
        my $name = sprintf "d2-dash-%d", $p * 1000 + 0.5;
        $period{$name} = $p;
        my $secs = sprintf "%.3f", $p / 9;
        $tag =~ s/\bstyle="/style="animation:$name ${secs}s linear infinite;/;
      }
      $tag
    }ge;
    my $keyframes = join "", map {
      sprintf "\@keyframes %s { from { stroke-dashoffset: %.6fpx; } to { stroke-dashoffset: 0; } }\n",
        $_, $period{$_}
    } sort keys %period;
    s{<svg\b[^>]*>}{$&<style type="text/css"><![CDATA[\n/* D2 Diagram Animations */\n$ENV{CSS}\n$keyframes]]></style>};
  ' "$svg"
  if ! grep -q "$marker" "$svg"; then
    echo "$svg: CSS injection failed" >&2
    exit 1
  fi
  echo "$svg: animated"
done
