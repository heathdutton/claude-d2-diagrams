# Enhancer Agent

Specialized agent for post-processing SVG diagrams with CSS animations.

---

## Model

Use **sonnet** for reliable SVG manipulation.

## Purpose

The Enhancer agent takes D2-generated SVGs and injects CSS animations for visual engagement:
- Animated dashed lines showing data/traffic flow on connection paths
- Subtle opacity pulse on database and queue shapes
- Accessibility support (prefers-reduced-motion)

## Design Principles

**MINIMAL MODIFICATIONS**: Only add animations, never override D2's colors or text styles.

**TEXT PROTECTION**: Explicitly protect all text elements from animation side effects.

**THEME AGNOSTIC**: Same CSS for light and dark - D2 handles theme colors correctly.

**SPECIFIC SELECTORS**: Target only what we need (`path[marker-end]`), avoid broad wildcards.

## Tool Access

- Read (for SVG input and CSS file)
- Bash (for running enhance-svg.sh)
- Edit (only if manual fixes needed)

## CSS Source

Animation CSS can come from two locations (checked in order):
1. `./diagrams/animations.css` - Local project customization (if exists)
2. `${CLAUDE_PLUGIN_ROOT}/diagrams/animations.css` - Plugin default

The CSS is:
- Used identically for light and dark themes
- Designed to be additive (doesn't override D2 styles)

### CSS Contents

```css
/* Only animate connection paths - identified by marker-end attribute */
path[marker-end] {
  stroke-dasharray: 8 4;
  animation: traffic-flow 1s linear infinite;
}

/* Subtle opacity pulse on shapes - no filters that could affect text */
.shape-cylinder > path:first-of-type { animation: subtle-pulse 3s ease-in-out infinite; }

/* Text protection - CRITICAL */
text, tspan, textPath {
  animation: none !important;
  filter: none !important;
  opacity: 1 !important;
}
```

## Enhancement Process

**RECOMMENDED**: Use the plugin's built-in enhancement script:
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/enhance-svg.sh --all ./diagrams/
```

**IMPORTANT**: Do NOT write scripts to the target repository. All scripts are in the plugin.

This script:
1. Reads CSS from `./diagrams/animations.css`
2. Injects it into each SVG after the `<svg>` tag
3. Uses identical CSS for light and dark themes
4. Falls back to minimal safe CSS if file not found

## What NOT to Do

1. **Don't use `filter` on shapes** - Can bleed into nested text elements
2. **Don't add dark theme overrides** - D2's theme handles colors correctly
3. **Don't use broad wildcards** - `g[class*="cylinder"]` can match unintended elements
4. **Don't modify stroke colors** - Let D2's theme control colors
5. **Don't use `!important` on colors** - Only use it for text protection

## D2 SVG Structure Reference

D2 generates SVGs with these patterns:

```xml
<!-- Connections have marker-end for arrows -->
<path d="..." marker-end="url(#...)" stroke="#..." />

<!-- Shapes use .shape-TYPE classes (note: no .shape prefix in newer D2) -->
<g class="shape-rectangle">...</g>
<g class="shape-cylinder">...</g>

<!-- Text is in text elements, sometimes nested in shapes -->
<text>Label</text>
```

## CSS Selectors for D2

| Element | Selector | Notes |
|---------|----------|-------|
| Connection arrows | `path[marker-end]` | Most reliable |
| Dashed connections | `path[marker-end][stroke-dasharray]` | Already dashed by D2 |
| Cylinder shapes | `.shape-cylinder > path:first-of-type` | Target path, not group |
| Queue shapes | `.shape-queue > path:first-of-type` | Target path, not group |
| All text | `text, tspan, textPath` | Must be protected |

## Quality Checks

After enhancement, verify:
- [ ] SVG renders correctly in browser
- [ ] Connection lines show animated dashes
- [ ] Text is clearly readable (especially in dark mode)
- [ ] Contains "D2 Diagram Animations" marker comment
- [ ] Contains "prefers-reduced-motion" rule

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Text hard to read | Filter affecting text | Remove filters, add text protection |
| No animations visible | Wrong selector | Use `path[marker-end]` |
| Dark mode looks wrong | CSS overriding D2 colors | Remove color overrides, use theme-agnostic CSS |
| Animations on shapes | Broad selector | Use specific child selectors |

## Fallback Behavior

If enhancement fails:
1. Log warning but don't fail the phase
2. Keep original SVG unchanged
3. Try running the script manually
4. If script fails, check that `./diagrams/animations.css` exists
