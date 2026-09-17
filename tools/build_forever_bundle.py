#!/usr/bin/env python3
"""build_forever_bundle.py -- Forever datamine viewer + shareable zip builder.

WHAT:  turns the community datamine package (wowheadScrape/dbc_extract/
        forever_community/, built by tools/build_forever_database.py) into
        (1) index.html, a self-contained offline Wowhead-style spell/talent/
        race viewer (single file, no network, works from file://), and
        (2) forever-datamine-<version>.zip bundling the viewer, the data
        files, the rotation bridge and a generated friend-facing README
        (FRIENDS_README_TEMPLATE below -- the maintainer README never ships;
        it references repo paths friends don't have).
WHEN:  beta day 2026-09-17+; rebuild after every datamine refresh.
WHY:   the database files are maintainer-oriented; friends and fellow
        developers get one zip to unzip and double-click.
SAFETY: read-only against the package inputs; writes only inside
        forever_community/ (gitignored bulk-data area -- only this script is
        tracked). Deterministic output (sorted ids) so rebuilds diff cleanly.
        No third-party dependencies (stdlib only).

Usage:
    python tools/build_forever_bundle.py            # viewer + zip
    python tools/build_forever_bundle.py --check    # verify bundle + zip
"""

import argparse
import html
import json
import os
import re
import sqlite3
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PKG = os.path.join(ROOT, "wowheadScrape", "dbc_extract", "forever_community")
DB_PATH = os.path.join(PKG, "forever_datamine.db")
TALENTS_PATH = os.path.join(PKG, "talents.json")
RACES_PATH = os.path.join(PKG, "races.json")
README_SRC = os.path.join(
    ROOT, "EaxRotations", "docs", "forever", "datamine", "README.md")
BRIDGE_SRC = os.path.join(
    ROOT, "EaxRotations", "shared",
    "wowhead_data_bridge_spell_index_forever_sylvanas.lua")

VIEWER_NAME = "index.html"

CLASS_COLORS = {
    "Warrior": "#C79C6E", "Paladin": "#F58CBA", "Hunter": "#ABD473",
    "Rogue": "#FFF569", "Priest": "#FFFFFF", "Death Knight": "#C41F3B",
    "Shaman": "#0070DE", "Mage": "#69CCF0", "Warlock": "#9482C9",
    "Druid": "#FF7D0A",
}

# Effect ids with DBC-verified meaning on this client (see the datamine
# README quirks); everything else renders as a raw "effect N" row.
EFFECT_HINTS = {2: "damage", 6: "apply aura", 10: "heal"}

TOKEN_RE = re.compile(r"\$[A-Za-z0-9${}/.+\-]+")
SCRIPT_CLOSE_RE = re.compile(r"</script", re.IGNORECASE)


def render_desc(text):
    """Escape tooltip text, then highlight $tokens. Runs at BUILD time so
    the viewer needs no runtime escaping logic."""
    safe = html.escape(text or "", quote=True)
    return TOKEN_RE.sub(lambda m: "<code>%s</code>" % m.group(0), safe)


def load_package():
    if not os.path.exists(DB_PATH):
        print("ERROR: datamine DB not found: %s" % DB_PATH)
        print("       Run tools/build_forever_database.py first.")
        sys.exit(2)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        meta = dict(conn.execute("SELECT k, v FROM meta").fetchall())
        spells = []
        for r in conn.execute(
                "SELECT s.id, s.name, s.class, s.level, r.rank_no, s.school,"
                " s.cooldown_s, s.gcd_s, s.description, s.aura_description,"
                " s.is_heal, s.aoe FROM player_spells s "
                "JOIN spell_ranks r ON r.spell_id = s.id ORDER BY s.id"):
            d = dict(r)
            effs = []
            for e in conn.execute(
                    "SELECT idx, effect, aura, base_points, misc, targets,"
                    " trigger_spell, radius, coefficient FROM spell_effects"
                    " WHERE spell_id = ? ORDER BY idx", (d["id"],)):
                ed = dict(e)
                effs.append([ed["idx"], ed["effect"], ed["aura"],
                             ed["base_points"], ed["misc"], ed["targets"],
                             ed["trigger_spell"]])
            # Other ranks of the same (class, name) ladder for the chip row.
            ladder = [x["spell_id"] for x in conn.execute(
                "SELECT r2.spell_id FROM spell_ranks r1 "
                "JOIN spell_ranks r2 ON r2.name = r1.name "
                "AND COALESCE(r2.class,'') = COALESCE(r1.class,'') "
                "WHERE r1.spell_id = ? ORDER BY r2.rank_no", (d["id"],))]
            spells.append({
                "id": d["id"], "name": d["name"], "class": d["class"],
                "level": d["level"], "rank": d["rank_no"],
                "school": d["school"], "cd": d["cooldown_s"],
                "gcd": d["gcd_s"],
                "desc": render_desc(d["description"]),
                "auradesc": render_desc(d["aura_description"]),
                "heal": bool(d["is_heal"]), "aoe": bool(d["aoe"]),
                "effects": effs, "ladder": ladder,
            })
    finally:
        conn.close()
    with open(TALENTS_PATH, encoding="utf-8") as f:
        talents = json.load(f)
    with open(RACES_PATH, encoding="utf-8") as f:
        races = json.load(f)
    return spells, talents, races, meta


def blob(obj):
    """Compact JSON safe to embed in an application/json script block."""
    return SCRIPT_CLOSE_RE.sub("<\\/script", json.dumps(obj, ensure_ascii=False,
                                                        separators=(",", ":")))


HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>WoW Forever Datamine — beta {VERSION}</title>
<style>
:root { color-scheme: dark; }
body { background: #0d1117; color: #c9d1d9; font: 14px/1.45 -apple-system, "Segoe UI", sans-serif; margin: 0; }
header { background: #161b22; border-bottom: 1px solid #30363d; padding: 12px 20px; }
header h1 { font-size: 18px; margin: 0 0 2px; }
header p { margin: 0; color: #8b949e; font-size: 12px; }
nav { display: flex; gap: 6px; padding: 10px 20px 0; }
nav button { background: #21262d; color: #c9d1d9; border: 1px solid #30363d; border-radius: 6px; padding: 6px 14px; cursor: pointer; }
nav button.active { background: #1f6feb; border-color: #1f6feb; color: #fff; }
main { padding: 14px 20px 40px; max-width: 1100px; }
.tab { display: none; }
.tab.active { display: block; }
.controls { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 12px; align-items: center; }
.controls input[type=text] { background: #0d1117; border: 1px solid #30363d; color: #c9d1d9; border-radius: 6px; padding: 6px 10px; width: 280px; }
.chip { border: 1px solid #30363d; border-radius: 12px; padding: 3px 10px; font-size: 12px; cursor: pointer; background: #21262d; }
.chip.on { background: #1f6feb; border-color: #1f6feb; color: #fff; }
#results { display: flex; flex-direction: column; gap: 6px; }
.row { background: #161b22; border: 1px solid #30363d; border-radius: 6px; padding: 8px 12px; cursor: pointer; display: flex; gap: 10px; align-items: baseline; }
.row:hover { border-color: #58a6ff; }
.row .nm { font-weight: 600; }
.row .meta { color: #8b949e; font-size: 12px; margin-left: auto; white-space: nowrap; }
#detail { margin-top: 14px; }
.tooltip { background: #000; border: 1px solid #434343; border-radius: 4px; padding: 10px 12px; max-width: 420px; }
.tooltip h3 { margin: 0 0 2px; font-size: 15px; color: #ffd100; }
.tooltip .sub { color: #9d9d9d; font-size: 12px; margin-bottom: 6px; }
.tooltip .desc { color: #ffd100; margin: 6px 0; }
.tooltip .desc code { color: #71d5ff; }
.tooltip table { border-collapse: collapse; width: 100%; font-size: 12px; margin-top: 6px; }
.tooltip th, .tooltip td { border: 1px solid #333; padding: 3px 6px; text-align: left; }
.tooltip th { color: #9d9d9d; font-weight: normal; }
.ladder { margin-top: 8px; font-size: 12px; color: #8b949e; }
.ladder button { background: #21262d; color: #58a6ff; border: 1px solid #30363d; border-radius: 4px; margin: 2px; padding: 2px 8px; cursor: pointer; }
.ladder button.cur { color: #fff; border-color: #58a6ff; }
table.grid { border-collapse: collapse; width: 100%; font-size: 13px; }
table.grid th, table.grid td { border: 1px solid #30363d; padding: 5px 8px; text-align: left; vertical-align: top; }
table.grid th { background: #161b22; color: #8b949e; font-weight: normal; }
.tier { margin-bottom: 10px; }
.tier h4 { margin: 8px 0 4px; color: #8b949e; font-weight: normal; }
.note { color: #8b949e; font-size: 12px; }
.sky { color: #71d5ff; font-weight: 600; }
.count { color: #8b949e; font-size: 12px; margin-bottom: 8px; }
</style>
</head>
<body>
<header><h1>WoW Forever Datamine</h1><p>beta {VERSION} &middot; extracted {DATE} &middot; {NSPELLS} player spells &middot; {NTALENTS} talents &middot; offline file, no network</p></header>
<nav>
<button data-tab="spells" class="active">Spells</button>
<button data-tab="talents">Talents</button>
<button data-tab="races">Races</button>
<button data-tab="about">About</button>
</nav>
<main>
<section id="tab-spells" class="tab active">
<div class="controls">
<input type="text" id="q" placeholder="Search name or spell id…" autocomplete="off">
<span id="classchips"></span>
<span class="chip" id="f-heal">heals</span>
<span class="chip" id="f-aoe">aoe</span>
</div>
<div class="count" id="count"></div>
<div id="results"></div>
<div id="detail"></div>
</section>
<section id="tab-talents" class="tab">
<div class="controls"><span id="talclass"></span></div>
<div id="talentlist"></div>
</section>
<section id="tab-races" class="tab"><div id="racelist"></div></section>
<section id="tab-about" class="tab">
<h3>About this datamine</h3>
<p>Spell/talent/trainer/race rows read off the Forever beta client data
(beta {VERSION}); descriptions are verbatim client text (<code>$s1</code>-style
tokens kept raw). See <code>README.md</code> next to this file for the data
files, usage recipes, and known data quirks (rank-1 vs rank order, one name
covering several roles, aura-name gaps).</p>
<h3>Effect legend (DBC-verified on this client)</h3>
<p><code>2</code> damage &middot; <code>6</code> apply aura &middot;
<code>10</code> heal. All other effect ids render raw — see README.md.</p>
<p class="note">Cooldowns live in two DBC columns; a blank cooldown here means
the DBC carries no row, not "no cooldown". Mana costs are %-of-base-mana on
the client and are not part of the extracted tables.</p>
</section>
</main>
<script type="application/json" id="d-spells">{SPELLS}</script>
<script type="application/json" id="d-talents">{TALENTS}</script>
<script type="application/json" id="d-races">{RACES}</script>
<script type="application/json" id="d-meta">{META}</script>
<script>
"use strict";
var SPELLS = JSON.parse(document.getElementById("d-spells").textContent);
var TALENTS = JSON.parse(document.getElementById("d-talents").textContent);
var RACES = JSON.parse(document.getElementById("d-races").textContent);
var META = JSON.parse(document.getElementById("d-meta").textContent);
var CLASS_COLORS = {CLASS_COLORS};
var EFFECT_HINTS = {EFFECT_HINTS};
var state = { cls: null, heal: false, aoe: false };
function esc(s) {
  return String(s == null ? "" : s).replace(/&/g, "&amp;").replace(/</g, "&lt;")
    .replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
function byId(id) {
  for (var i = 0; i < SPELLS.length; i++) if (SPELLS[i].id === id) return SPELLS[i];
  return null;
}
function filtered() {
  var q = document.getElementById("q").value.trim().toLowerCase();
  var out = [];
  for (var i = 0; i < SPELLS.length; i++) {
    var s = SPELLS[i];
    if (state.cls && s["class"] !== state.cls) continue;
    if (state.heal && !s.heal) continue;
    if (state.aoe && !s.aoe) continue;
    if (q) {
      if (/^\\d+$/.test(q)) { if (s.id !== (+q)) continue; }
      else if (s.name.toLowerCase().indexOf(q) < 0) continue;
    }
    out.push(s);
    if (out.length >= 200) break;
  }
  return out;
}
function renderList() {
  var list = filtered();
  document.getElementById("count").textContent =
    list.length + (list.length >= 200 ? "+ (capped — refine the search)" : "") + " of " + SPELLS.length;
  var html = "";
  for (var i = 0; i < list.length; i++) {
    var s = list[i];
    var color = CLASS_COLORS[s["class"]] || "#c9d1d9";
    html += '<div class="row" data-id="' + s.id + '"><span class="nm" style="color:' + color + '">'
      + esc(s.name) + '</span><span class="meta">R' + s.rank + ' &middot; lvl ' + s.level
      + ' &middot; ' + esc(s.school) + (s.cd != null ? ' &middot; ' + s.cd + 's CD' : '') + '</span></div>';
  }
  document.getElementById("results").innerHTML = html;
  var rows = document.getElementById("results").children;
  for (var j = 0; j < rows.length; j++) {
    rows[j].onclick = (function(el) { return function() { showDetail(+el.getAttribute("data-id")); }; })(rows[j]);
  }
}
function showDetail(id) {
  var s = byId(id);
  if (!s) return;
  var color = CLASS_COLORS[s["class"]] || "#c9d1d9";
  var h = '<div class="tooltip"><h3 style="color:' + color + '">' + esc(s.name) + '</h3>'
    + '<div class="sub">Rank ' + s.rank + ' &middot; requires level ' + s.level
    + ' &middot; ' + esc(s.school) + ' &middot; id ' + s.id + '</div>';
  h += '<div>GCD ' + (s.gcd != null ? s.gcd + 's' : '—')
    + ' &middot; cooldown ' + (s.cd != null ? s.cd + 's' : '— (no DBC row)') + '</div>';
  if (s.desc) h += '<div class="desc">' + s.desc + '</div>';
  if (s.auradesc) h += '<div class="desc" style="color:#9d9d9d">' + s.auradesc + '</div>';
  h += '<table><tr><th>#</th><th>effect</th><th>aura</th><th>base</th><th>targets</th><th>trigger</th></tr>';
  for (var i = 0; i < s.effects.length; i++) {
    var e = s.effects[i];
    var hint = EFFECT_HINTS[e[1]] ? ' (' + EFFECT_HINTS[e[1]] + ')' : '';
    h += '<tr><td>' + e[0] + '</td><td>' + e[1] + esc(hint) + '</td><td>' + e[2] + '</td><td>'
      + e[3] + '</td><td>[' + e[5][0] + ',' + e[5][1] + ']</td><td>' + (e[6] || '—') + '</td></tr>';
  }
  h += '</table>';
  if (s.ladder && s.ladder.length > 1) {
    h += '<div class="ladder">ranks: ';
    for (var k = 0; k < s.ladder.length; k++) {
      var rid = s.ladder[k];
      h += '<button data-id="' + rid + '"' + (rid === s.id ? ' class="cur"' : '') + '>R' + (k + 1) + '</button>';
    }
    h += '</div>';
  }
  h += '</div>';
  var box = document.getElementById("detail");
  box.innerHTML = h;
  var btns = box.getElementsByTagName("button");
  for (var b = 0; b < btns.length; b++) {
    btns[b].onclick = (function(el) { return function() { showDetail(+el.getAttribute("data-id")); }; })(btns[b]);
  }
  box.scrollIntoView();
}
function renderTalents(cls) {
  var html = "";
  for (var i = 0; i < TALENTS.length; i++) {
    var t = TALENTS[i];
    if (t["class"] !== cls) continue;
    html += '<div class="tier"><h4>' + esc(t.tab) + '</h4><table class="grid"><tr><th>tier</th><th>col</th><th>ranks</th></tr>';
    for (var j = 0; j < t.talents.length; j++) {
      var tal = t.talents[j];
      var names = [];
      for (var k = 0; k < tal.spells.length; k++) {
        names.push(esc(tal.spells[k].name || ("#" + tal.spells[k].id)));
      }
      html += '<tr><td>' + tal.tier + '</td><td>' + tal.column + '</td><td>' + names.join(" → ") + '</td></tr>';
    }
    html += '</table></div>';
  }
  document.getElementById("talentlist").innerHTML = html || '<p class="note">No tabs.</p>';
}
function renderRaces() {
  var html = '<table class="grid"><tr><th>race</th><th>id</th><th>faction</th><th>starts</th><th>playable</th></tr>';
  for (var i = 0; i < RACES.length; i++) {
    var r = RACES[i];
    var sky = /skyborne/i.test(r.name) ? ' class="sky"' : '';
    html += '<tr' + sky + '><td>' + esc(r.name) + '</td><td>' + r.id + '</td><td>'
      + r.faction + '</td><td>' + r.starting_level + '</td><td>' + (r.playable ? 'yes' : '—') + '</td></tr>';
  }
  document.getElementById("racelist").innerHTML = html + '</table>';
}
function init() {
  var tabs = document.querySelectorAll("nav button");
  for (var i = 0; i < tabs.length; i++) {
    tabs[i].onclick = (function(el) {
      return function() {
        for (var j = 0; j < tabs.length; j++) tabs[j].classList.remove("active");
        el.classList.add("active");
        var secs = document.querySelectorAll("main .tab");
        for (var k = 0; k < secs.length; k++) secs[k].classList.remove("active");
        document.getElementById("tab-" + el.getAttribute("data-tab")).classList.add("active");
      };
    })(tabs[i]);
  }
  var seen = {}, classes = [];
  for (var c = 0; c < SPELLS.length; c++) {
    if (!seen[SPELLS[c]["class"]]) { seen[SPELLS[c]["class"]] = 1; classes.push(SPELLS[c]["class"]); }
  }
  classes.sort();
  var chips = '<span class="chip on" data-cls="">all</span> ';
  for (var d = 0; d < classes.length; d++) {
    var color = CLASS_COLORS[classes[d]] || "#c9d1d9";
    chips += '<span class="chip" data-cls="' + esc(classes[d]) + '" style="color:' + color + '">' + esc(classes[d]) + '</span> ';
  }
  document.getElementById("classchips").innerHTML = chips;
  var all = document.getElementById("classchips").children;
  for (var e = 0; e < all.length; e++) {
    all[e].onclick = (function(el) {
      return function() {
        for (var f = 0; f < all.length; f++) all[f].classList.remove("on");
        el.classList.add("on");
        state.cls = el.getAttribute("data-cls") || null;
        renderList();
      };
    })(all[e]);
  }
  function toggle(id, key) {
    document.getElementById(id).onclick = function() {
      this.classList.toggle("on");
      state[key] = this.classList.contains("on");
      renderList();
    };
  }
  toggle("f-heal", "heal");
  toggle("f-aoe", "aoe");
  document.getElementById("q").oninput = renderList;
  var tclasses = [];
  for (var t = 0; t < TALENTS.length; t++) {
    if (tclasses.indexOf(TALENTS[t]["class"]) < 0) tclasses.push(TALENTS[t]["class"]);
  }
  tclasses.sort();
  var th = "";
  for (var u = 0; u < tclasses.length; u++) {
    th += '<span class="chip' + (u === 0 ? ' on' : '') + '" data-tc="' + esc(tclasses[u]) + '">' + esc(tclasses[u]) + '</span> ';
  }
  document.getElementById("talclass").innerHTML = th;
  var tc = document.getElementById("talclass").children;
  var pickTalent = function(cls) {
    for (var v = 0; v < tc.length; v++) {
      if (tc[v].getAttribute("data-tc") === cls) tc[v].classList.add("on");
      else tc[v].classList.remove("on");
    }
    renderTalents(cls);
  };
  for (var w = 0; w < tc.length; w++) {
    tc[w].onclick = (function(el) { return function() { pickTalent(el.getAttribute("data-tc")); }; })(tc[w]);
  }
  renderList();
  renderTalents(tclasses[0]);
  renderRaces();
}
if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
else init();
</script>
</body>
</html>
"""


# Friend-facing README shipped inside the zip (generated per build so the
# version/date/counts can't go stale). Rule: only paths that exist INSIDE
# the zip -- never repo paths, tool commands, or maintainer jargon. The
# --check below scans the shipped README for leaks.
FRIENDS_README_TEMPLATE = """# WoW Forever Datamine — beta {VERSION}

Spell, talent, trainer, race and proc data read straight from the WoW
Forever beta client files (build {VERSION}, extracted {DATE} UTC). No
guessing, no fansite scraping — every number here is what the client
itself ships.

If the beta patches, this package goes stale: compare the version in the
folder name against your client build.

## Start here

Unzip anywhere, then double-click **`index.html`**. It works fully offline
in any modern browser — no server, no internet needed:

- **Spells** tab: search by name or spell id, filter by class, heals, AoE.
  Click a row for the full tooltip (client text verbatim), the raw effect
  table, and buttons to walk the whole rank ladder.
- **Talents** tab: all {NTALENTS} talents across 27 trees (9 classes x 3),
  tier/column with rank-spell names.
- **Races** tab: every race on the client, playable flag + starting level.
- **About** tab: effect-id legend and caveats, repeated below.
- **Beyond the viewer**: the `data/` folder carries the full item catalogue,
  the zone/flight/POI place index and per-spell metadata (cast time, range,
  mana, ...). Browse them with DB Browser for SQLite or any text editor —
  recipes below.

## What's in this folder

| File / folder | What it is |
|---|---|
| `index.html` | The offline browser above (all data embedded). |
| `README.md` | This file. |
| `data/forever_datamine.db` | SQLite database: `spells`, `spell_effects`, `spell_ranks`, `talents`, `trainer_spells`, `races`, `procs` tables plus handy `player_spells` / `heals` views. Open with DB Browser for SQLite (free, sqlitebrowser.org). |
| `data/spells.jsonl` | One JSON object per line for every named spell — plain-text searchable in any editor. |
| `data/by_name.json` | Spell name → every spell id using it (sorted). Answers "which id is the real max rank?". |
| `data/talents.json` | Talent trees with rank-spell names + descriptions joined in. |
| `data/trainers.json` | What each class trainer teaches, with required levels. |
| `data/races.json` | All client races, playable flag, starting level. |
| `data/procs.json` | Proc/aura-chance rows (chance, charges, type) with spell names joined. |
| `data/items.jsonl` | Every named item ({NITEMS} rows): quality, item level, required level, class/subclass, slot, stat types + budget percents, prices, set id. |
| `data/spell_meta.json` | Per-spell extras keyed by id: cast time, duration, range, radius, target cap, dispel/mechanic, mana cost, interrupt flags. |
| `data/zones.json` | Every zone/area with its map and parent area. |
| `data/points.json` | Place index: points of interest, area triggers and flight masters with world coordinates. |
| `data/taxi.json` | Flight network: nodes with coordinates plus every flight path (cost, waypoint count). |
| `data/creatures.json` | Companion creatures with type/family, the pet families, and level ranges. |
| `bridge/` | Lua spell-id table used by a rotation addon project — only interesting if you develop Lua rotations/addons; everyone else can ignore it. |

## Try it (no special tools needed)

SQLite — open `data/forever_datamine.db` in DB Browser for SQLite, tab
"Execute SQL":

```sql
-- Every Holy Strike rank, weakest to strongest:
SELECT spell_id, rank_no, level FROM spell_ranks
 WHERE name = 'Holy Strike' AND class = 'Paladin' ORDER BY rank_no;
-- Every direct heal a Resto Shaman can cast:
SELECT id, name, level, cooldown_s FROM heals WHERE class = 'Shaman';
-- Full tooltip + mechanic rows for one spell:
SELECT description FROM spells WHERE id = 11078;
SELECT effect, aura, base_points, targets FROM spell_effects WHERE spell_id = 11078;
-- Items by name, with slot and item level (helper view):
SELECT id, name, quality, ilvl, req_level, inv_type FROM item_index
 WHERE name LIKE 'Thunderfury%';
-- Flight masters of one map, with coordinates:
SELECT Name_lang, Pos FROM TaxiNodes WHERE ContinentID = 0 ORDER BY Name_lang;
```

Text search — `data/spells.jsonl` is one object per line, so Ctrl+F works in
any editor:

```
"name": "Holy Strike"          # every Holy Strike row
"name": "Touch of the Grave"   # racial proc rows
```

## Read this before theorycrafting (data quirks)

- **Rank 1 is not the lowest id.** A few classic ladders number out of
  order: Holy Strike rank 1 is spell 679 (level 6), not 678 (level 12);
  Consecration rank 1 is 26573 (level 20), not 20116 (level 30). The viewer
  walks ladders in true rank order — trust the R1/R2/... chips, not the ids.
- **One name, several different spells.** The client reuses names across
  roles: Arcane Blast is both an aura (400573) and a nuke (400574);
  Missile Barrage is a talent (400588) and a proc (400589); same story for
  Maelstrom Weapon. Hot Streak additionally keeps a legacy row (48108)
  beside the real proc (400625). Always check the effect table / tooltip
  before citing an id.
- **Blank cooldown does NOT mean no cooldown.** Cooldowns live in two client
  columns and only one is extracted here (Holy Shock, Holy Strike and Lava
  Burst keep theirs in the other one). A blank cell means "no data", not
  "spammable".
- **Item stat numbers are computed by the game, not stored.** The item files
  carry stat types and budget percentages; the game turns those into final
  numbers from item level and quality. Treat them as relative weights and
  check final values in-game.
- **Tooltip `$s1`-style tokens are verbatim** client text — the numbers they
  stand for resolve in-game, not in this package.
- **No hotfix data.** The beta ships no usable hotfix cache for its own
  build, so this is base client data; numbers can still move before launch.
- **Items are not included** (the beta's item-property table doesn't extract
  cleanly yet) — spells, talents, trainers, races and procs only.

## Where this came from

Read directly off the Forever beta client data files on {DATE} (UTC) and
rebuilt from scratch after every beta patch. If your client is newer than
{VERSION}, ask whoever sent you this for a fresh pack.
"""


def build_friends_readme(meta, nspells, ntalents, nitems):
    date = meta.get("extracted_at_utc", "?")
    if date.endswith(" UTC"):
        date = date[:-len(" UTC")]
    return (FRIENDS_README_TEMPLATE
            .replace("{VERSION}", meta.get("client_version", "?"))
            .replace("{DATE}", date)
            .replace("{NSPELLS}", str(nspells))
            .replace("{NITEMS}", str(nitems))
            .replace("{NTALENTS}", str(ntalents)))


def build_viewer(spells, talents, races, meta):
    compact = []
    for s in spells:
        compact.append({
            "id": s["id"], "name": s["name"], "class": s["class"],
            "level": s["level"], "rank": s["rank"], "school": s["school"],
            "cd": s["cooldown_s"], "gcd": s["gcd_s"],
            "desc": render_desc(s["description"]),
            "auradesc": render_desc(s["aura_description"]),
            "heal": s["is_heal"], "aoe": s["aoe"],
            "effects": [[e["idx"], e["effect"], e["aura"], e["base_points"],
                         e["misc"], e["targets"], e["trigger_spell"]]
                        for e in s["effects"]],
            "ladder": s["ladder"],
        })
    slim_talents = []
    for t in talents:
        slim_talents.append({
            "class": t["class"], "tab": t["tab"],
            "talents": [{"tier": x["tier"], "column": x["column"],
                         "spells": [{"id": r["id"], "name": r["name"]}
                                    for r in x["spell_ranks"]]}
                        for x in t["talents"]],
        })
    slim_races = [{"id": r["id"], "name": r["name"],
                   "faction": r["faction"],
                   "starting_level": r["starting_level"],
                   "playable": r["playable"]} for r in races]
    tokens = {
        "{VERSION}": html.escape(meta.get("client_version", "?")),
        "{DATE}": html.escape(meta.get("extracted_at_utc", "?")),
        "{NSPELLS}": str(len([s for s in spells if s["class"]])),
        "{NTALENTS}": str(sum(len(t["talents"]) for t in talents)),
        "{SPELLS}": blob(compact),
        "{TALENTS}": blob(slim_talents),
        "{RACES}": blob(slim_races),
        "{META}": blob({"version": meta.get("client_version", "?"),
                        "build": meta.get("client_build", "?")}),
        "{CLASS_COLORS}": json.dumps(CLASS_COLORS),
        "{EFFECT_HINTS}": json.dumps({2: "damage", 6: "apply aura",
                                      10: "heal"}),
    }
    page = HTML_TEMPLATE
    for token, value in tokens.items():
        assert page.count(token) >= 1, token
        page = page.replace(token, value)
    return page


def load_inputs():
    import sqlite3
    db_path = os.path.join(PKG, "forever_datamine.db")
    if not os.path.exists(db_path):
        print("ERROR: datamine DB not found: %s" % db_path)
        print("       Run tools/build_forever_database.py first.")
        sys.exit(2)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    try:
        spells = []
        for r in conn.execute(
                "SELECT s.*, r.rank_no FROM player_spells s "
                "JOIN spell_ranks r ON r.spell_id = s.id ORDER BY s.id"):
            d = dict(r)
            d["effects"] = [dict(e) for e in conn.execute(
                "SELECT * FROM spell_effects WHERE spell_id = ? ORDER BY idx",
                (d["id"],))]
            ladder = [x["spell_id"] for x in conn.execute(
                "SELECT r2.spell_id FROM spell_ranks r1 "
                "JOIN spell_ranks r2 ON r2.name = r1.name AND "
                "COALESCE(r2.class,'') = COALESCE(r1.class,'') "
                "WHERE r1.spell_id = ? ORDER BY r2.rank_no", (d["id"],))]
            d["ladder"] = ladder
            spells.append(d)
        talents = json.load(open(os.path.join(PKG, "talents.json"),
                                 encoding="utf-8"))
        races = json.load(open(os.path.join(PKG, "races.json"),
                               encoding="utf-8"))
        meta = dict(conn.execute("SELECT k, v FROM meta").fetchall())
    finally:
        conn.close()
    return spells, talents, races, meta


def zip_name(meta):
    return "forever-datamine-%s.zip" % (meta.get("client_version", "unknown")
                                        .replace(".", "_"))


def build_all():
    spells, talents, races, meta = load_inputs()
    shaped = []
    for s in spells:
        shaped.append({
            "id": s["id"], "name": s["name"], "class": s["class"],
            "level": s["level"], "rank": s["rank_no"], "school": s["school"],
            "cooldown_s": s["cooldown_s"], "gcd_s": s["gcd_s"],
            "description": s["description"] or "",
            "aura_description": s["aura_description"] or "",
            "is_heal": bool(s["is_heal"]), "aoe": bool(s["aoe"]),
            "effects": s["effects"], "ladder": s["ladder"],
        })
    return build_viewer(shaped, talents, races, meta), spells, talents, races, meta


ZIP_MEMBERS = ("forever_datamine.db", "spells.jsonl", "by_name.json",
               "talents.json", "trainers.json", "races.json", "procs.json",
               "items.jsonl", "spell_meta.json", "zones.json", "points.json",
               "taxi.json", "creatures.json")


def build_zip(page, meta, nspells, ntalents):
    """Write index.html + assemble the shareable zip. Returns zip path."""
    with open(os.path.join(PKG, VIEWER_NAME), "w", encoding="utf-8",
              newline="\n") as f:
        f.write(page)
    top = "forever-datamine-%s" % meta.get("client_version", "unknown")
    zpath = os.path.join(PKG, top + ".zip")
    items_path = os.path.join(PKG, "items.jsonl")
    nitems = 0
    if os.path.exists(items_path):
        with open(items_path, encoding="utf-8") as f:
            nitems = sum(1 for _ in f)
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(os.path.join(PKG, VIEWER_NAME), top + "/" + VIEWER_NAME)
        z.writestr(top + "/README.md",
                   build_friends_readme(meta, nspells, ntalents, nitems))
        if os.path.exists(BRIDGE_SRC):
            z.write(BRIDGE_SRC, top + "/bridge/" + os.path.basename(BRIDGE_SRC))
        for member in ZIP_MEMBERS:
            src = os.path.join(PKG, member)
            if not os.path.exists(src):
                print("ERROR: package file missing (run build_forever_database.py): %s" % src)
                sys.exit(2)
            z.write(src, top + "/data/" + member)
    return zpath


def check_bundle():
    """Verify viewer + zip (exit codes mirror build_forever_bridge)."""
    problems = []
    vpath = os.path.join(PKG, VIEWER_NAME)
    if not os.path.exists(vpath):
        return ["viewer missing: run without --check first"]
    with open(vpath, encoding="utf-8") as f:
        page = f.read()
    blobs = {}
    for key in ("d-spells", "d-talents", "d-races", "d-meta"):
        m = re.search(r'<script type="application/json" id="%s">(.*?)</script>'
                      % key, page, re.S)
        if not m:
            problems.append("viewer lacks embedded block %s" % key)
            continue
        try:
            blobs[key] = json.loads(m.group(1))
        except ValueError as e:
            problems.append("viewer block %s is not valid JSON: %s" % (key, e))
    if "d-spells" in blobs:
        n = len(blobs["d-spells"])
        if n < 1000:
            problems.append("viewer embeds only %d spells" % n)
        ids = {s["id"] for s in blobs["d-spells"]}
        # Player-spell spots only: Twist of Light (1310735) carries no class
        # set on the client, so it is correctly absent from player data.
        for spot in (678, 20163, 1310909, 408490, 8349, 48108, 400573,
                     408498, 400588):
            if spot not in ids:
                problems.append("viewer data missing spot id %d" % spot)
    zips = sorted(f for f in os.listdir(PKG) if f.endswith(".zip"))
    if not zips:
        problems.append("no bundle zip present")
    else:
        with zipfile.ZipFile(os.path.join(PKG, zips[-1])) as z:
            names = set(z.namelist())
            top = zips[-1][:-len(".zip")]
            want = {top + "/" + VIEWER_NAME, top + "/README.md"}
            want |= {top + "/data/" + m for m in ZIP_MEMBERS}
            missing = sorted(want - names)
            if missing:
                problems.append("zip lacks members: %s" % missing)
            readme = ""
            try:
                readme = z.read(top + "/README.md").decode("utf-8")
            except KeyError:
                problems.append("zip README.md unreadable")
            if readme:
                # The shipped README is friend-facing: any repo-internal
                # reference is a leak (friends only have the zip).
                for marker in ("wowheadScrape", "EaxRotations", "tools/",
                               "dbc_runbook", "repo law", "DB2ToSqlite",
                               "dotnet", "--check"):
                    if marker in readme:
                        problems.append(
                            "zip README.md leaks internal ref %r" % marker)
                if "{VERSION}" in readme or "{NSPELLS}" in readme:
                    problems.append("zip README.md has unfilled template tokens")
    # Same leak rule for the viewer About tab (spell descriptions are
    # client text and never contain these markers).
    for marker in ("EaxRotations/docs", "tools/build_forever"):
        if marker in page:
            problems.append("viewer leaks internal ref %r" % marker)
    if problems:
        for p in problems:
            print("FAIL:", p)
        return 1
    print("OK: Forever bundle verified (%s)" % zips[-1])
    return 0


def main():
    parser = argparse.ArgumentParser(description="Forever datamine viewer + shareable zip")
    parser.add_argument("--check", action="store_true",
                        help="verify viewer + zip")
    args = parser.parse_args()
    if args.check:
        sys.exit(check_bundle())
    page, spells, talents, races, meta = build_all()
    nspells = len([s for s in spells if s["class"]])
    ntalents = sum(len(t["talents"]) for t in talents)
    zpath = build_zip(page, meta, nspells, ntalents)
    print("Viewer:  %s (%s bytes)" % (
        os.path.join(PKG, VIEWER_NAME),
        format(os.path.getsize(os.path.join(PKG, VIEWER_NAME)), ",")))
    print("Zip:     %s (%s bytes)" % (
        zpath, format(os.path.getsize(zpath), ",")))
    print("Spells embedded: %d player spells" % len(spells))
    sys.exit(check_bundle())


if __name__ == "__main__":
    main()
