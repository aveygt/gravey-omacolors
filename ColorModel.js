// Pure color math for the Omarchy color picker.
// Hex <-> RGB <-> HSV <-> HSL, plus palette load/save helpers.
// Qt-free so it can be unit tested under Node.

function clamp(value, min, max) {
  var n = Number(value)
  if (!isFinite(n)) return min
  return Math.max(min, Math.min(max, n))
}

function roundInt(value) {
  return Math.round(Number(value) || 0)
}

var HISTORY_SIZE = 8

function defaultPalette() {
  return [
    "#1A1B26",
    "#24283B",
    "#414868",
    "#C0CAF5",
    "#FFFFFF",
    "#F7768E",
    "#FF9E64",
    "#E0AF68",
    "#9ECE6A",
    "#73DACA",
    "#7AA2F7",
    "#BB9AF7"
  ]
}

function emptyHistory() {
  var slots = []
  for (var i = 0; i < HISTORY_SIZE; i++) slots.push("")
  return slots
}

function defaultState() {
  return {
    current: "#7AA2F7",
    history: emptyHistory(),
    colors: defaultPalette()
  }
}

function hexChannel(value) {
  var n = clamp(roundInt(value), 0, 255)
  var hex = n.toString(16).toUpperCase()
  return hex.length === 1 ? "0" + hex : hex
}

function hexFromRgb(r, g, b) {
  return "#" + hexChannel(r) + hexChannel(g) + hexChannel(b)
}

function normalizeHex(value) {
  var raw = String(value || "").trim()
  if (raw.charAt(0) === "#") raw = raw.slice(1)
  if (!/^[0-9A-Fa-f]{3}$/.test(raw) && !/^[0-9A-Fa-f]{6}$/.test(raw))
    return ""
  if (raw.length === 3) {
    raw = raw.charAt(0) + raw.charAt(0) + raw.charAt(1) + raw.charAt(1) + raw.charAt(2) + raw.charAt(2)
  }
  return "#" + raw.toUpperCase()
}

function extractHex(raw) {
  var text = String(raw || "").replace(/\u001b\[[0-9;]*m/g, "")
  var hash = text.match(/#[0-9A-Fa-f]{6}/)
  if (hash) return normalizeHex(hash[0])
  var bare = text.match(/\b[0-9A-Fa-f]{6}\b/)
  if (bare) return normalizeHex(bare[0])
  var rgb = text.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/i)
  if (rgb) return hexFromRgb(Number(rgb[1]), Number(rgb[2]), Number(rgb[3]))
  var shortHash = text.match(/#[0-9A-Fa-f]{3}\b/)
  if (shortHash) return normalizeHex(shortHash[0])
  return normalizeHex(text)
}

function rgbFromHex(hex) {
  var normalized = normalizeHex(hex)
  if (!normalized) return { r: 0, g: 0, b: 0 }
  return {
    r: parseInt(normalized.slice(1, 3), 16),
    g: parseInt(normalized.slice(3, 5), 16),
    b: parseInt(normalized.slice(5, 7), 16)
  }
}

function hsvFromRgb(r, g, b) {
  var rr = clamp(r, 0, 255) / 255
  var gg = clamp(g, 0, 255) / 255
  var bb = clamp(b, 0, 255) / 255
  var max = Math.max(rr, gg, bb)
  var min = Math.min(rr, gg, bb)
  var delta = max - min
  var h = 0
  if (delta !== 0) {
    if (max === rr) h = ((gg - bb) / delta) % 6
    else if (max === gg) h = (bb - rr) / delta + 2
    else h = (rr - gg) / delta + 4
    h *= 60
    if (h < 0) h += 360
  }
  return {
    h: h,
    s: max === 0 ? 0 : delta / max,
    v: max
  }
}

function rgbFromHsv(h, s, v) {
  var hue = ((Number(h) % 360) + 360) % 360
  var sat = clamp(s, 0, 1)
  var val = clamp(v, 0, 1)
  var c = val * sat
  var x = c * (1 - Math.abs((hue / 60) % 2 - 1))
  var m = val - c
  var rr = 0
  var gg = 0
  var bb = 0
  if (hue < 60) { rr = c; gg = x }
  else if (hue < 120) { rr = x; gg = c }
  else if (hue < 180) { gg = c; bb = x }
  else if (hue < 240) { gg = x; bb = c }
  else if (hue < 300) { rr = x; bb = c }
  else { rr = c; bb = x }
  return {
    r: roundInt((rr + m) * 255),
    g: roundInt((gg + m) * 255),
    b: roundInt((bb + m) * 255)
  }
}

function hslFromRgb(r, g, b) {
  var rr = clamp(r, 0, 255) / 255
  var gg = clamp(g, 0, 255) / 255
  var bb = clamp(b, 0, 255) / 255
  var max = Math.max(rr, gg, bb)
  var min = Math.min(rr, gg, bb)
  var delta = max - min
  var h = 0
  if (delta !== 0) {
    if (max === rr) h = ((gg - bb) / delta) % 6
    else if (max === gg) h = (bb - rr) / delta + 2
    else h = (rr - gg) / delta + 4
    h *= 60
    if (h < 0) h += 360
  }
  var l = (max + min) / 2
  var s = delta === 0 ? 0 : delta / (1 - Math.abs(2 * l - 1))
  return { h: h, s: s, l: l }
}

function hexFromHsv(h, s, v) {
  var rgb = rgbFromHsv(h, s, v)
  return hexFromRgb(rgb.r, rgb.g, rgb.b)
}

function hsvFromHex(hex) {
  var rgb = rgbFromHex(hex)
  return hsvFromRgb(rgb.r, rgb.g, rgb.b)
}

function formatRgb(r, g, b) {
  return "rgb(" + clamp(roundInt(r), 0, 255) + ", " + clamp(roundInt(g), 0, 255) + ", " + clamp(roundInt(b), 0, 255) + ")"
}

function formatPercent(value) {
  return String(roundInt(clamp(value, 0, 1) * 100))
}

function formatHsl(h, s, l) {
  return "hsl(" + roundInt(h) + ", " + formatPercent(s) + "%, " + formatPercent(l) + "%)"
}

function formatHsv(h, s, v) {
  return "hsv(" + roundInt(h) + ", " + formatPercent(s) + "%, " + formatPercent(v) + "%)"
}

function cmykFromRgb(r, g, b) {
  var rr = clamp(r, 0, 255) / 255
  var gg = clamp(g, 0, 255) / 255
  var bb = clamp(b, 0, 255) / 255
  var k = 1 - Math.max(rr, gg, bb)
  if (k >= 1) return { c: 0, m: 0, y: 0, k: 1 }
  return {
    c: (1 - rr - k) / (1 - k),
    m: (1 - gg - k) / (1 - k),
    y: (1 - bb - k) / (1 - k),
    k: k
  }
}

function formatCmyk(c, m, y, k) {
  return formatPercent(c) + "%, " + formatPercent(m) + "%, " + formatPercent(y) + "%, " + formatPercent(k) + "%"
}

function formatDegreePercent(h, a, b) {
  return roundInt(h) + "°, " + formatPercent(a) + "%, " + formatPercent(b) + "%"
}

function formatsForHex(hex) {
  var normalized = normalizeHex(hex) || "#000000"
  var rgb = rgbFromHex(normalized)
  var hsl = hslFromRgb(rgb.r, rgb.g, rgb.b)
  var hsv = hsvFromRgb(rgb.r, rgb.g, rgb.b)
  var cmyk = cmykFromRgb(rgb.r, rgb.g, rgb.b)
  return {
    hex: normalized,
    hexLower: normalized.toLowerCase(),
    rgb: formatRgb(rgb.r, rgb.g, rgb.b),
    rgbDisplay: rgb.r + ", " + rgb.g + ", " + rgb.b,
    hsl: formatHsl(hsl.h, hsl.s, hsl.l),
    hslDisplay: formatDegreePercent(hsl.h, hsl.s, hsl.l),
    hsv: formatHsv(hsv.h, hsv.s, hsv.v),
    hsvDisplay: formatDegreePercent(hsv.h, hsv.s, hsv.v),
    cmyk: "cmyk(" + formatCmyk(cmyk.c, cmyk.m, cmyk.y, cmyk.k) + ")",
    cmykDisplay: formatCmyk(cmyk.c, cmyk.m, cmyk.y, cmyk.k)
  }
}

function formatRows(hex) {
  var formats = formatsForHex(hex)
  return [
    { key: "hex", label: "HEX", value: formats.hexLower, display: formats.hexLower },
    { key: "rgb", label: "RGB", value: formats.rgb, display: formats.rgbDisplay },
    { key: "cmyk", label: "CMYK", value: formats.cmyk, display: formats.cmykDisplay },
    { key: "hsv", label: "HSV", value: formats.hsv, display: formats.hsvDisplay },
    { key: "hsl", label: "HSL", value: formats.hsl, display: formats.hslDisplay }
  ]
}

function svFromPointer(x, y, width, height) {
  return {
    s: clamp(Number(x) / Math.max(1, width), 0, 1),
    v: 1 - clamp(Number(y) / Math.max(1, height), 0, 1)
  }
}

function pointerFromSv(s, v, width, height) {
  return {
    x: clamp(s, 0, 1) * width,
    y: (1 - clamp(v, 0, 1)) * height
  }
}

function hueFromPointer(x, width) {
  return clamp(Number(x) / Math.max(1, width), 0, 1) * 360
}

function normalizeHistory(values) {
  var next = emptyHistory()
  var source = Array.isArray(values) ? values : []
  for (var i = 0; i < HISTORY_SIZE && i < source.length; i++) {
    next[i] = normalizeHex(source[i]) || ""
  }
  return next
}

function historyFromLegacyColors(colors) {
  var next = emptyHistory()
  var source = Array.isArray(colors) ? colors : []
  var seen = {}
  var filled = 0
  for (var i = 0; i < source.length && filled < HISTORY_SIZE; i++) {
    var hex = normalizeHex(source[i])
    if (!hex || seen[hex]) continue
    seen[hex] = true
    next[filled] = hex
    filled += 1
  }
  return next
}

function setHistorySlot(history, index, hex) {
  var next = normalizeHistory(history)
  if (index < 0 || index >= HISTORY_SIZE) return next
  next[index] = normalizeHex(hex) || ""
  return next
}

function saveToHistory(history, hex) {
  var normalized = normalizeHex(hex)
  var next = normalizeHistory(history)
  if (!normalized) return next

  for (var i = 0; i < HISTORY_SIZE; i++) {
    if (next[i] === normalized) return next
  }

  for (var j = 0; j < HISTORY_SIZE; j++) {
    if (!next[j]) {
      next[j] = normalized
      return next
    }
  }

  for (var k = HISTORY_SIZE - 1; k > 0; k--) next[k] = next[k - 1]
  next[0] = normalized
  return next
}

function parseState(raw) {
  var fallback = defaultState()
  var parsed = null
  try {
    parsed = typeof raw === "string" ? JSON.parse(raw || "{}") : raw
  } catch (error) {
    return fallback
  }
  if (!parsed || typeof parsed !== "object") return fallback

  var colors = []
  var source = Array.isArray(parsed.colors) ? parsed.colors : []
  var seen = {}
  for (var i = 0; i < source.length; i++) {
    var hex = normalizeHex(source[i])
    if (!hex || seen[hex]) continue
    seen[hex] = true
    colors.push(hex)
  }

  var history = Array.isArray(parsed.history)
    ? normalizeHistory(parsed.history)
    : (colors.length ? historyFromLegacyColors(colors) : emptyHistory())

  var current = normalizeHex(parsed.current) || fallback.current
  return { current: current, history: history, colors: colors }
}

function paletteHas(colors, hex) {
  var normalized = normalizeHex(hex)
  if (!normalized || !Array.isArray(colors)) return false
  for (var i = 0; i < colors.length; i++) {
    if (normalizeHex(colors[i]) === normalized) return true
  }
  return false
}

function addPaletteColor(colors, hex) {
  var normalized = normalizeHex(hex)
  var next = []
  var source = Array.isArray(colors) ? colors : []
  for (var i = 0; i < source.length; i++) {
    var existing = normalizeHex(source[i])
    if (existing) next.push(existing)
  }
  if (normalized && !paletteHas(next, normalized)) next.push(normalized)
  return next
}

function removePaletteColor(colors, hex) {
  var normalized = normalizeHex(hex)
  var next = []
  var source = Array.isArray(colors) ? colors : []
  for (var i = 0; i < source.length; i++) {
    var existing = normalizeHex(source[i])
    if (existing && existing !== normalized) next.push(existing)
  }
  return next
}

function hsvFromPointer(x, y, size) {
  var radius = size / 2
  var dx = Number(x) - radius
  var dy = Number(y) - radius
  var dist = Math.sqrt(dx * dx + dy * dy)
  var hue = (Math.atan2(dy, dx) * 180 / Math.PI + 360) % 360
  var sat = radius <= 0 ? 0 : clamp(dist / radius, 0, 1)
  return { h: hue, s: sat }
}

function pointerFromHsv(h, s, size) {
  var radius = size / 2
  var hue = ((Number(h) % 360) + 360) % 360
  var sat = clamp(s, 0, 1)
  var rad = hue * Math.PI / 180
  return {
    x: radius + Math.cos(rad) * sat * radius,
    y: radius + Math.sin(rad) * sat * radius
  }
}
