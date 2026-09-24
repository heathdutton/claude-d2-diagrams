#!/usr/bin/env python3
"""Rewrites the <image href="data:image/svg+xml;base64,..."> icons d2 embeds into nested <svg> markup.

GitHub serves repository SVGs with `Content-Security-Policy: default-src 'none'`. Browsers that
apply that policy inside an SVG image drop data: subresources and leave the icon blank, while
nested <svg> markup has no subresource to block. Every icon is sanitized and scoped so it cannot
reach the rest of the diagram:

  - only SVG and xlink markup survives (editor metadata, scripts and foreign namespaces go)
  - ids and class names get a per-icon prefix, and so do the references to them
  - every CSS selector in the icon's <style> is anchored to the icon's wrapper id

An icon that fails to decode or sanitize keeps its original <image>, and a file that would come
out malformed is left untouched with a non-zero exit. Written for the Python 3.9 that macOS ships.

Usage: inline-svg-icons.py FILE.svg...
"""
import base64
import binascii
import gzip
import re
import sys
import xml.parsers.expat
from xml.sax.saxutils import escape

SVG_NS = "http://www.w3.org/2000/svg"
XLINK_NS = "http://www.w3.org/1999/xlink"
XML_NS = "http://www.w3.org/XML/1998/namespace"
KNOWN_PREFIXES = {"xlink": XLINK_NS, "xml": XML_NS}

IMAGE_TAG = re.compile(r'<image\b[^>]*?\bhref="data:image/svg\+xml;base64,([^"]+)"[^>]*?/?>(?:</image>)?')
URL_REF = re.compile(r"""url\(\s*['"]?#([^)'"\s]+)['"]?\s*\)""")
CSS_RULE = re.compile(r"([^{};]+)\{")
CSS_CLASS = re.compile(r"\.(-?[_a-zA-Z][\w-]*)")
CSS_ID = re.compile(r"#(-?[_a-zA-Z][\w-]*)")
KEYFRAME_SEL = re.compile(r"^(from|to|[\d.]+%)$")
NUMERIC = re.compile(r"^[\d.]+")

# Elements that carry no drawing, or that must never ride into a README image.
DROPPED = {"metadata", "title", "desc", "script", "foreignObject"}
# Kept, but on their own they paint nothing.
NON_DRAWING = {
    "defs", "style", "linearGradient", "radialGradient", "stop",
    "clipPath", "mask", "symbol", "pattern", "filter",
}
# Inheritable paint the icon's root may set for all its children.
ROOT_PAINT = [
    "fill", "fill-rule", "fill-opacity", "stroke", "stroke-width", "stroke-linecap",
    "stroke-linejoin", "stroke-miterlimit", "stroke-opacity", "opacity",
]


class IconError(Exception):
    pass


def attr(value):
    return '"' + escape(value, {'"': "&quot;"}) + '"'


def split(name):
    """Returns (namespace, local) for an expat name in either namespace mode."""
    if " " in name:
        ns, local = name.rsplit(" ", 1)
        return ns, local
    if ":" in name:
        prefix, local = name.split(":", 1)
        return KNOWN_PREFIXES.get(prefix, prefix), local
    return "", name


def kept_attr(name):
    ns, local = split(name)
    if name.startswith("xmlns") or local.lower().startswith("on"):
        return None
    if ns == "":
        return local
    if ns == XLINK_NS:
        return "xlink:" + local
    if ns == XML_NS:
        return "xml:" + local
    return None


def scope_css(css, prefix):
    """Prefixes url(#id) references, and anchors every rule's selectors under the wrapper id with
    renamed classes and ids, so `.cls-1{...}` from one icon cannot paint another."""
    css = URL_REF.sub(lambda m: "url(#%s-%s)" % (prefix, m.group(1)), css)

    def rule(m):
        if m.group(1).strip().startswith("@"):
            return m.group(0)
        selectors = []
        for sel in m.group(1).split(","):
            sel = sel.strip()
            if sel and not KEYFRAME_SEL.match(sel):
                sel = CSS_ID.sub(lambda i: "#%s-%s" % (prefix, i.group(1)), sel)
                sel = "#%s %s" % (prefix, CSS_CLASS.sub(lambda c: ".%s-%s" % (prefix, c.group(1)), sel))
            selectors.append(sel)
        return ",".join(selectors) + "{"

    return CSS_RULE.sub(rule, css)


def rewrite_attr(name, value, prefix):
    if name == "id":
        return "%s-%s" % (prefix, value)
    if name == "class":
        return " ".join("%s-%s" % (prefix, c) for c in value.split())
    if name in ("href", "xlink:href"):
        if value.startswith("#"):
            return "#%s-%s" % (prefix, value[1:])
        return value if value.startswith("data:") else ""
    if name == "style":
        return scope_css(value, prefix)
    return URL_REF.sub(lambda m: "url(#%s-%s)" % (prefix, m.group(1)), value)


def decode_payload(b64):
    """Returns the icon's SVG bytes. d2 releases before 0.9 embedded the CDN's gzip body verbatim,
    so gzip is unwrapped here; any other encoding is refused rather than inlined as binary."""
    try:
        data = base64.b64decode(b64 + "=" * (-len(b64) % 4))
    except (binascii.Error, ValueError) as err:
        raise IconError("bad base64: %s" % err)
    if data[:2] == b"\x1f\x8b":
        data = gzip.decompress(data)
    if b"<svg" not in data:
        raise IconError("payload is not SVG markup (compressed by the icon host? d2 0.9+ fetches it decoded)")
    return data


def sanitize(data, prefix):
    """Re-serializes the icon's children with prefixed ids and classes, and returns the root <svg>
    attributes separately so the caller can build the wrapper."""
    try:
        return walk(data, prefix, namespaces=True)
    except xml.parsers.expat.ExpatError:
        # Editor exports sometimes use a prefix they never declare; read those without namespaces.
        return walk(data, prefix, namespaces=False)


def walk(data, prefix, namespaces):
    parser = xml.parsers.expat.ParserCreate(namespace_separator=" " if namespaces else None)
    parser.buffer_text = True
    out, root = [], {}
    state = {"root": False, "drew": False, "depth": 0, "skip": 0, "style": False}

    def start(name, attrs):
        if state["skip"]:
            state["skip"] += 1
            return
        ns, local = split(name)
        if not state["root"]:
            if local != "svg":
                raise IconError("root element is <%s>, not <svg>" % local)
            state["root"] = True
            for key, value in attrs.items():
                if split(key)[0] == "" and not key.startswith("xmlns"):
                    root[key] = value
            return
        if ns not in ("", SVG_NS) or local in DROPPED:
            state["skip"] = 1
            return
        state["depth"] += 1
        state["drew"] = state["drew"] or local not in NON_DRAWING
        out.append("<" + local)
        for key, value in attrs.items():
            kept = kept_attr(key)
            if kept:
                out.append(" %s=%s" % (kept, attr(rewrite_attr(kept, value, prefix))))
        out.append(">")
        state["style"] = local == "style"

    def end(name):
        if state["skip"]:
            state["skip"] -= 1
            return
        if state["depth"] == 0:
            return
        state["depth"] -= 1
        out.append("</%s>" % split(name)[1])
        state["style"] = False

    def chars(text):
        if state["skip"] or state["depth"] == 0:
            return
        out.append(escape(scope_css(text, prefix) if state["style"] else text))

    parser.StartElementHandler = start
    parser.EndElementHandler = end
    parser.CharacterDataHandler = chars
    parser.Parse(data, True)
    if not state["root"]:
        raise IconError("no <svg> root")
    if not state["drew"]:
        raise IconError("no drawable element survived sanitizing")
    return "".join(out), root


def attr_of(tag, name, fallback):
    m = re.search(r"\s%s=\"([^\"]*)\"" % name, tag)
    return m.group(1) if m else fallback


def well_formed(doc):
    parser = xml.parsers.expat.ParserCreate(namespace_separator=" ")
    try:
        parser.Parse(doc, True)
    except xml.parsers.expat.ExpatError as err:
        raise IconError(str(err))


def inline_icon(tag, prefix):
    inner, root = sanitize(decode_payload(IMAGE_TAG.match(tag).group(1)), prefix)
    x, y = attr_of(tag, "x", "0"), attr_of(tag, "y", "0")
    w, h = attr_of(tag, "width", "64"), attr_of(tag, "height", "64")
    view_box = root.get("viewBox", "")
    if not view_box:
        rw, rh = NUMERIC.match(root.get("width", "")), NUMERIC.match(root.get("height", ""))
        view_box = "0 0 %s %s" % ((rw.group(0), rh.group(0)) if rw and rh else (w, h))

    parts = ['<svg id="%s" x="%s" y="%s" width="%s" height="%s" viewBox=%s' % (prefix, x, y, w, h, attr(view_box))]
    if root.get("preserveAspectRatio"):
        parts.append(" preserveAspectRatio=%s" % attr(root["preserveAspectRatio"]))
    # A nested <svg> inherits paint from the diagram, where an <image> started from SVG defaults,
    # so the defaults are restated and whatever paint the icon's root set rides along.
    root.setdefault("fill", "#000")
    root.setdefault("stroke", "none")
    for name in ROOT_PAINT:
        if root.get(name):
            parts.append(" %s=%s" % (name, attr(rewrite_attr(name, root[name], prefix))))
    if root.get("style"):
        parts.append(" style=%s" % attr(scope_css(root["style"], prefix)))
    parts.append(' xmlns:xlink="%s">%s</svg>' % (XLINK_NS, inner))
    snippet = "".join(parts)
    well_formed('<svg xmlns="%s" xmlns:xlink="%s">%s</svg>' % (SVG_NS, XLINK_NS, snippet))
    return snippet


def inline_file(path):
    with open(path, encoding="utf-8") as f:
        content = f.read()
    counter = {"all": 0, "kept": 0}

    def replace(m):
        counter["all"] += 1
        try:
            return inline_icon(m.group(0), "d2icon%d" % counter["all"])
        except (IconError, xml.parsers.expat.ExpatError, OSError, EOFError) as err:
            print("%s: icon %d left as <image>: %s" % (path, counter["all"], err), file=sys.stderr)
            counter["kept"] += 1
            return m.group(0)

    out = IMAGE_TAG.sub(replace, content)
    if counter["all"] == 0:
        return
    try:
        well_formed(out)
    except IconError as err:
        raise IconError("result would be malformed, file left untouched: %s" % err)
    with open(path, "w", encoding="utf-8") as f:
        f.write(out)
    print("%s: inlined %d of %d icons" % (path, counter["all"] - counter["kept"], counter["all"]))


def main(paths):
    if not paths:
        print("usage: inline-svg-icons.py FILE.svg...", file=sys.stderr)
        return 2
    failed = False
    for path in paths:
        try:
            inline_file(path)
        except (IconError, OSError) as err:
            print("%s: %s" % (path, err), file=sys.stderr)
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
