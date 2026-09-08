// Tests for ColorModel.js — the pure half of the color picker.
//
//   node tests/run.js

const fs = require("fs")
const path = require("path")
const vm = require("vm")
const assert = require("assert")

const source = fs.readFileSync(path.join(__dirname, "..", "ColorModel.js"), "utf8")

const before = new Set(Object.getOwnPropertyNames(globalThis))
vm.runInThisContext(source, { filename: "ColorModel.js" })

const Model = {}
for (const name of Object.getOwnPropertyNames(globalThis)) {
  if (!before.has(name)) Model[name] = globalThis[name]
}

let passed = 0
const failures = []

function test(name, fn) {
  try {
    fn()
    passed += 1
  } catch (error) {
    failures.push({ name: name, error: error })
  }
}

const eq = assert.deepStrictEqual

test("normalizeHex expands short hex", () => {
  eq(Model.normalizeHex("#abc"), "#AABBCC")
  eq(Model.normalizeHex("ff00aa"), "#FF00AA")
  eq(Model.normalizeHex("not-a-color"), "")
})

test("hexFromRgb and rgbFromHex round-trip", () => {
  const hex = Model.hexFromRgb(18, 171, 239)
  eq(hex, "#12ABEF")
  eq(Model.rgbFromHex(hex), { r: 18, g: 171, b: 239 })
})

test("hsv red and white", () => {
  const red = Model.hsvFromRgb(255, 0, 0)
  eq(Math.round(red.h), 0)
  eq(red.s, 1)
  eq(red.v, 1)
  eq(Model.hexFromHsv(0, 1, 1), "#FF0000")

  const white = Model.hsvFromRgb(255, 255, 255)
  eq(white.s, 0)
  eq(white.v, 1)
  eq(Model.hexFromHsv(120, 0, 1), "#FFFFFF")
})

test("formatsForHex includes css-style strings", () => {
  const formats = Model.formatsForHex("#12ABEF")
  eq(formats.hex, "#12ABEF")
  eq(formats.hexLower, "#12abef")
  eq(formats.rgb, "rgb(18, 171, 239)")
  assert.match(formats.hsl, /^hsl\(\d+, \d+%, \d+%\)$/)
  assert.match(formats.hsv, /^hsv\(\d+, \d+%, \d+%\)$/)
  assert.match(formats.cmykDisplay, /^\d+%, \d+%, \d+%, \d+%$/)
})

test("formatRows order is hex rgb cmyk hsv hsl", () => {
  const rows = Model.formatRows("#FFFFFF")
  eq(rows.map((row) => row.key), ["hex", "rgb", "cmyk", "hsv", "hsl"])
  eq(rows[0].display, "#ffffff")
  eq(rows[1].display, "255, 255, 255")
})

test("cmyk black and the reference green", () => {
  eq(Model.cmykFromRgb(0, 0, 0), { c: 0, m: 0, y: 0, k: 1 })
  const mint = Model.rgbFromHex("#2BFBB0")
  const cmyk = Model.cmykFromRgb(mint.r, mint.g, mint.b)
  eq(Model.formatCmyk(cmyk.c, cmyk.m, cmyk.y, cmyk.k), "83%, 0%, 30%, 2%")
})

test("parseState recovers current and 8 history slots", () => {
  const state = Model.parseState(JSON.stringify({
    current: "#abc",
    history: ["#FF0000", "", "#00FF00"]
  }))
  eq(state.current, "#AABBCC")
  eq(state.history, ["#FF0000", "", "#00FF00", "", "", "", "", ""])
})

test("parseState migrates legacy palette colors into history", () => {
  const state = Model.parseState(JSON.stringify({
    current: "#abc",
    colors: ["#FF0000", "#ff0000", "nope", "#00FF00"]
  }))
  eq(state.current, "#AABBCC")
  eq(state.history, ["#FF0000", "#00FF00", "", "", "", "", "", ""])
})

test("parseState falls back on junk", () => {
  const state = Model.parseState("not json")
  eq(state.current, Model.defaultState().current)
  eq(state.history, Model.emptyHistory())
})

test("saveToHistory fills the first empty slot then shifts", () => {
  const first = Model.saveToHistory(Model.emptyHistory(), "#00ff00")
  eq(first[0], "#00FF00")
  eq(Model.saveToHistory(first, "#00ff00"), first)

  const full = ["#111111", "#222222", "#333333", "#444444", "#555555", "#666666", "#777777", "#888888"]
  const shifted = Model.saveToHistory(full, "#abcdef")
  eq(shifted[0], "#ABCDEF")
  eq(shifted[1], "#111111")
  eq(shifted[7], "#777777")
})

test("history slot save and clear", () => {
  const saved = Model.setHistorySlot(Model.emptyHistory(), 0, "#00ff00")
  eq(saved[0], "#00FF00")
  eq(saved.length, 8)
  eq(Model.setHistorySlot(saved, 0, ""), Model.emptyHistory())
})

test("extractHex reads messy picker output", () => {
  eq(Model.extractHex("#2bfbb0\n"), "#2BFBB0")
  eq(Model.extractHex("picked 2BFBB0"), "#2BFBB0")
  eq(Model.extractHex("rgb(43, 251, 176)"), "#2BFBB0")
})

test("palette add and remove", () => {
  const added = Model.addPaletteColor(["#FF0000"], "#00ff00")
  eq(added, ["#FF0000", "#00FF00"])
  eq(Model.addPaletteColor(added, "#00FF00"), added)
  eq(Model.removePaletteColor(added, "#ff0000"), ["#00FF00"])
  eq(Model.paletteHas(added, "#00ff00"), true)
})

test("sv and hue pointer mapping", () => {
  const sv = Model.svFromPointer(200, 0, 200, 100)
  eq(sv.s, 1)
  eq(sv.v, 1)
  const point = Model.pointerFromSv(1, 1, 200, 100)
  eq(point.x, 200)
  eq(point.y, 0)
  eq(Math.round(Model.hueFromPointer(100, 200)), 180)
})

if (failures.length) {
  for (const failure of failures) {
    console.error("FAIL", failure.name)
    console.error(failure.error)
  }
  process.exit(1)
}

console.log("ok", passed, "tests")
