---
name: diagram
description: Diagrams of this repo's architecture and infrastructure, kept fresh in ./diagrams. Use when asked to diagram, map or document the system's architecture or infrastructure, or when ./diagrams is reported stale.
argument-hint: "[--full] [--check] [--ci] [--infrastructure-only | --architecture-only] [--scope=<path>]"
allowed-tools:
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/*)
  - Bash("${CLAUDE_PLUGIN_ROOT}/scripts/*)
  - Bash(d2 *)
  - Bash(git diff *)
  - Bash(git log *)
  - Read
  - Glob
  - Grep
  - Edit(diagrams/**)
  - Edit(README.md)
---

# Diagrams

`./diagrams` holds four docs, four D2 sources, eight SVGs (light and dark), a landing page, and `manifest.json`, which records the commit they were built from and the paths they depend on. The code is the ground truth. Existing docs and diagrams are hints that may have gone stale.

## Status

!`"${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"`

Arguments: $ARGUMENTS

## Mode

- `--check`: report the status above in two lines and stop.
- `--ci`: follow [ci.md](ci.md) and stop.
- `state: fresh` without `--full`: say the diagrams are current as of the manifest commit and stop.
- `state: new`, `unknown-base` or `bad-sources`, or `--full`: **build** every artifact from scratch.
- `state: stale` or `legacy`: **refresh**, a surgical update driven by the changed files listed above.

`--infrastructure-only` and `--architecture-only` limit every step to one family. `--scope=<path>` goes into every documenter brief.

If the status has an `animations:` line, delete the file it names before rendering. If it has an `icons:` line, move every icon to the new host, whose paths are identical: `perl -pi -e 's#icons\.terrastruct\.com#icons.d2lang.com#g' diagrams/*.d2`.

The `d2:` line must end in `ok` before any step runs. Otherwise run the install or upgrade command it names, then re-run `"${CLAUDE_PLUGIN_ROOT}/scripts/status.sh"`. The `python3:` line must end in `ok` too, since icons are inlined with it: run the command it names.

## Steps

Dispatch the agents with the Agent tool in the foreground: several Agent calls in one message already run in parallel, and a headless run such as CI stops waiting on background agents after ten minutes. Every brief carries the mode and, for a refresh, the changed-file lines from the status above. The agents' results are short blocks: keep them for the report and the stamp.

1. **Document.** In one message, dispatch `d2:documenter` for `infrastructure` and for `architecture`. In a refresh, skip a family only when none of the changed files could bear on it.
   Done when each returns a status. A family that returns `unchanged` skips step 2, and step 3 too unless the state is `legacy`.
2. **Simplify.** In one message, dispatch `d2:documenter` with `model: sonnet` for the `-simplified` kind of each family whose detailed doc was written or updated, and name the sections that changed.
   Done when each returns a status.
3. **Render.** Dispatch one `d2:renderer` with every kind whose doc was written or updated. In a build, and in a `legacy` refresh, whose SVGs came from an older pipeline, that's every kind plus any other `.d2` the project keeps in `./diagrams`.
   Done when it returns `rendered` for each of those kinds.
4. **Verify.** Dispatch `d2:verifier` with the same kinds, the mode, the renderer's `png` directory, and the changed sections.
   Hand the `fix` findings to a fresh dispatch of whoever owns each file, a documenter for a `.md` and the renderer for a `.d2` (and the renderer again for any doc that changed). Then re-dispatch the verifier on those kinds, once. A `fix` that survives the second pass goes in the report.
5. **Embed.** In a build, or when `verify.sh` below reports a missing embed, follow [readme-embeds.md](readme-embeds.md).
6. **Gate.** Run `"${CLAUDE_PLUGIN_ROOT}/scripts/verify.sh"`, adding `--only <family>` for a single-family run, and fix what it names until it exits 0.
7. **Stamp.** Run `"${CLAUDE_PLUGIN_ROOT}/scripts/stamp.sh"` with the union of the documenters' `sources`. In a refresh, include the pathspecs already in `./diagrams/manifest.json`, so a family skipped this run keeps its sources.
   Skip the stamp on an `--infrastructure-only` or `--architecture-only` run: one commit covers both families, so stamping would mark the other family's drift as handled. Say so in the report.

## Report

Lead with the outcome: built, refreshed (which kinds changed), or already current. Then list only what needs the reader: surviving `fix` findings, `Unverified` counts, icons rendered without an image, and in a build, the one-line pointer that `/d2:diagram --ci` keeps diagrams fresh on every push.
