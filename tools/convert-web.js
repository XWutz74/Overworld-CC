#!/usr/bin/env node
/*
  Converts the browser game's content (data/*.js, lang/*.js) into Lua files for Overworld-CC.
  Usage: node tools/convert-web.js <path to the Overworld browser folder>
  Writes ow/data/world.lua, ow/data/presets.lua and ow/lang/<code>.lua.
  CC-only texts live in ow/lang/<code>_cc.lua and are not touched.
*/
"use strict";
const fs = require("fs"), path = require("path"), vm = require("vm");
const src = process.argv[2];
if (!src) { console.error("usage: node tools/convert-web.js <Overworld folder>"); process.exit(1); }
const out = path.join(__dirname, "..", "ow");

const ctx = {}; ctx.window = ctx;
vm.createContext(ctx);
const run = f => vm.runInContext(fs.readFileSync(path.join(src, f), "utf8"), ctx, { filename: f });
run("data/world.js"); run("data/presets.js");
const langs = fs.readdirSync(path.join(src, "lang")).filter(f => f.endsWith(".js"));
for (const f of langs) run("lang/" + f);
const OW = ctx.window.OW;

// ComputerCraft shows ISO-8859-1. Replace typographic characters it cannot show.
const MAP = { "„": '"', "“": '"', "”": '"', "‚": "'", "‘": "'", "’": "'", "–": "-", "—": "-", "−": "-", "…": "...", " ": " " };
const fix = s => s.replace(/[„“”‚‘’–—−… ]/g, c => MAP[c]);
for (const ch of JSON.stringify(OW)) if (ch.codePointAt(0) > 255 && !MAP[ch]) console.warn("warning: character not shown by CC:", ch);

const KW = new Set("and break do else elseif end false for function goto if in local nil not or repeat return then true until while".split(" "));
const key = k => /^[A-Za-z_][A-Za-z0-9_]*$/.test(k) && !KW.has(k) ? k : "[" + str(k) + "]";
const str = s => '"' + fix(String(s)).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n") + '"';
function lua(v, ind) {
  ind = ind || "";
  if (v === null || v === undefined) return "nil";
  if (typeof v === "string") return str(v);
  if (typeof v === "number" || typeof v === "boolean") return String(v);
  const inner = ind + "  ";
  if (Array.isArray(v)) {
    const flat = v.every(x => typeof x !== "object" || x === null);
    if (flat) return "{ " + v.map(x => lua(x)).join(", ") + " }";
    return "{\n" + v.map(x => inner + lua(x, inner)).join(",\n") + "\n" + ind + "}";
  }
  const ks = Object.keys(v);
  const small = ks.every(k => typeof v[k] !== "object" || (v[k] && !Array.isArray(v[k]) && Object.values(v[k]).every(x => typeof x !== "object")));
  const parts = ks.map(k => key(k) + " = " + lua(v[k], inner));
  const one = "{ " + parts.join(", ") + " }";
  if (small && one.length + ind.length < 160) return one;
  return "{\n" + parts.map(p => inner + p).join(",\n") + "\n" + ind + "}";
}
const head = (title, note) => `--[[\n  Overworld-CC - ${title}\n  Converted from the browser game by tools/convert-web.js.\n${note}]]\n`;

// Districts keep everything except the SVG map shapes.
const world = JSON.parse(JSON.stringify(OW.data.world));
for (const c of world.cities) for (const d of c.districts) { delete d.map; delete d.label; }

fs.writeFileSync(path.join(out, "data", "world.lua"), head("world content",
`  Cities, districts, goods, items, enemies, banks and loan sharks.
  Names use { en = "...", de = "..." }; "de" is optional. Money is in dollars,
  percentages are plain numbers (15 means 15 %).
  goods:   min/max normal price, lowSpike/highSpike crash/boom factor,
           avail chance (0-1) a district sells it, qty {smallest, largest}.
  items:   type storage|armor|vehicle|weapon|ammo|tool, space extra room,
           armor % absorbed, run escape bonus, notice extra encounter chance,
           violence only sold with violence on, sellable false = can't sell.
  enemies: count group size, hp, accuracy %, damage % per hit, bribe $ per member, loot.
  banks:   rate yearly %, min opening deposit and minimum balance.
  sharks:  rate daily %, days until due, amount range, early repayment fee %.
`) + "return " + lua(world) + "\n");

fs.writeFileSync(path.join(out, "data", "presets.lua"), head("difficulty presets",
`  economy: startCash/startDebt/loanRate/bankRate/volatility/costs are factors,
           spikeChance is the chance per good and day of a crash or boom.
  combat:  encounterChance % per day, enemyStrength/enemyCount factors,
           runBonus escape % points, arrestFine % of cash.
  lengths: game lengths in days, 0 = endless.
`) + "return " + lua(OW.data.presets) + "\n");

for (const code in OW.lang) {
  const L = OW.lang[code];
  const body = Object.keys(L).map(k => "  " + key(k) + " = " + str(L[k])).join(",\n");
  fs.writeFileSync(path.join(out, "lang", code + ".lua"), head("texts (" + code + ")",
`  Words in {curly braces} are filled in by the game. Leave them as they are.
  Missing texts fall back to English. CC-only texts: ${code}_cc.lua
`) + "return {\n" + body + "\n}\n");
}
console.log("written:", ["data/world.lua", "data/presets.lua"].concat(Object.keys(OW.lang).map(c => "lang/" + c + ".lua")).join(", "));
