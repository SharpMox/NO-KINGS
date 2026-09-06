// Diffs the Notion GDD catalogs (Artefacts, Items, Pieces, Tariffs) against
// their repo mirrors and prints a report of every disagreement. Report-only:
// this tool never writes to the repo or to Notion — the direction of truth
// (which side is stale) is a judgement call made by a human reading the
// report, not something this tool decides.
//
// Why it exists: this 40-issue backlog exists because the Notion GDD and the
// repo drifted apart unnoticed, and the drift has since been hand-fixed
// twice (once for the Items DB, once for artefact text) — the second fix
// still missed a row. Hand-checking 180 artefacts + 16 items + 39 pieces +
// 21 tariffs does not scale and fails silently.
//
// ---------------------------------------------------------------------------
// HOW TO PRODUCE THE SNAPSHOT (updated 2026-09-07 — the old recipe is dead)
// ---------------------------------------------------------------------------
// This tool takes Notion's data as an input file rather than fetching it:
//
//   node tools/check-notion-drift.mjs <snapshot.json>
//
// The header used to say "run these SQL queries through the Notion MCP".
// THE NOTION MCP WAS REMOVED on 2026-09-06 in favour of the signed-in browser,
// so that recipe cannot be followed. Gather the rows through agent-browser
// instead — see the global CLAUDE.md for the connect-mode launch.
//
// Database page URLs (NOT the collection:// ids the old recipe used — those
// are data sources and 404 as pages):
//
//   Artefacts       app.notion.com/p/dcfc4879530547c785278f198b85f3cb   (180 rows)
//   Items           app.notion.com/p/4bb01465387746e0beac20f382e7544c   (16)
//   Pieces          app.notion.com/p/a0cc1983c47541b6a92922f0113dc627   (39)
//   Tariffs Catalog app.notion.com/p/8906ed7b41da4b64a800f30af3494c8d   (21)
//
// Extract CELL-ALIGNED, never by splitting a row's innerText: an empty cell
// emits no line, so a split silently shifts every later column and manufactures
// drift that isn't there.
//
//   const rows = [...document.querySelectorAll('.notion-collection-item')];
//   const hdr  = [...document.querySelectorAll('.notion-table-view-header-cell')]
//                  .map(e => e.innerText.trim());
//   rows.map(r => {
//     const cells = [...r.querySelectorAll('.notion-table-view-cell')]
//                     .map(c => c.innerText.trim());
//     return Object.fromEntries(hdr.map((h, i) => [h, cells[i] ?? '']));
//   });
//
// Notion VIRTUALIZES rows: a short viewport renders only ~20. Scroll the list
// container and accumulate into a Set keyed on Name, or the 180-row Artefacts
// table will quietly return a window and every missing row reports as
// "in Notion only". Verify the count matches the table before trusting a run.
//
// Save as { "artefacts": [...], "items": [...], "pieces": [...], "tariffs": [...] }
// keyed on the exact Notion column names. A partial snapshot is fine if you
// only read that catalog's section — an omitted catalog reports every repo row
// as "in repo only", which is noise, not a finding.
//
// There is no committed snapshot fixture on purpose — a stale one would
// silently start lying, which is the exact failure mode this tool exists to
// catch.
//
// ---------------------------------------------------------------------------
// NORMALISATION — what counts as "different"
// ---------------------------------------------------------------------------
// Effect/description text on both sides sometimes carries a trailing ruling
// note that documents a past correction rather than changing the effect:
//   - repo (data/artefacts.js) appends inline, e.g. " (issue 16: Score is
//     up-only, so this penalty debits Gold instead)"
//   - Notion appends a whole extra paragraph after a blank line, e.g.
//     "...resets and -50 Gold\n\nRuling 2026-08-28 (issue 16): ..."
// Both are the same annotation in different houses, not drift, so text
// comparison here: (1) keeps only the text before the first blank line,
// (2) strips a trailing "(issue N: ...)" parenthetical, (3) collapses all
// whitespace to single spaces and trims. Applied identically to both sides
// so it can't hide a real difference that happens to look like a note.
//
// Tariffs' Description is compared too, but expect a wall of mismatches
// there: game/data/tariffs.gd's own header says its costs and wording are a
// deliberate paraphrase of the upstream Notion economy ("scaled ~/100 —
// flagged for a design pass"), not a verbatim mirror like Items/Artefacts.
// Name and Tier mismatches on Tariffs are the ones worth acting on.
//
// Artefacts' STATUS (the ?/BASIC/REWORK/KEEP/REMOVE design-triage select) is
// compared verbatim, no normalisation. It was left out originally and drifted
// silently: Manna Vending Machine and Apocrypha stayed REWORK in Notion long
// after their redesigns shipped (issues 58/65) and the repo said KEEP —
// invisible to this tool until 2026-09-04, when it was found by hand.
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const root = join(dirname(fileURLToPath(import.meta.url)), "..");

const snapshotPath = process.argv[2];
if (!snapshotPath) {
  console.error("usage: node tools/check-notion-drift.mjs <notion-snapshot.json>");
  console.error("(see this file's header for how to produce the snapshot)");
  process.exit(2);
}
const snapshot = JSON.parse(readFileSync(snapshotPath, "utf8"));

// ---- text normalisation --------------------------------------------------
function coreText(s) {
  if (s == null) return null;
  let core = String(s).split(/\r?\n\s*\r?\n/)[0]; // drop a trailing blank-line-separated ruling paragraph
  core = core.replace(/\s*\(issue \d+[^)]*\)\s*$/i, ""); // drop a trailing inline "(issue N ...)" note
  return core.replace(/\s+/g, " ").trim();
}
function normName(s) {
  if (s == null) return null;
  return String(s).replace(/[‘’]/g, "'").replace(/[“”]/g, '"').replace(/\s+/g, " ").trim();
}

// ---- GDScript array extraction (ITEMS / TARIFFS are JSON-shaped Godot dict
// literals with no comments inside them, so a trailing-comma fix + JSON.parse
// reads them without a real GDScript parser) --------------------------------
function extractGdArray(text, constName) {
  const re = new RegExp(`const ${constName}\\s*:?\\s*Array\\s*=\\s*(\\[[\\s\\S]*?\\n\\])`, "m");
  const m = text.match(re);
  if (!m) throw new Error(`could not find "const ${constName}: Array = [...]" block`);
  const block = m[1].replace(/,(\s*[\]}])/g, "$1"); // strip trailing commas before ] or }
  return JSON.parse(block);
}

// ---- load repo sides --------------------------------------------------
const artefactsJs = require(join(root, "data/artefacts.js"));
const piecesJs = require(join(root, "data/pieces-codex.js"));
const itemsGd = readFileSync(join(root, "game/data/items.gd"), "utf8");
const tariffsGd = readFileSync(join(root, "game/data/tariffs.gd"), "utf8");
const itemsArr = extractGdArray(itemsGd, "ITEMS");
const tariffsArr = extractGdArray(tariffsGd, "TARIFFS");

// ---- generic two-sided diff ------------------------------------------------
// notionRows/repoRows: arrays of plain objects already reduced to {key, fields...}
// fields: [[label, notionField, repoField, {compare}]]
function diffCatalog(name, notionRows, repoRows, fields) {
  const lines = [];
  const notionByKey = new Map(notionRows.map((r) => [r.key, r]));
  const repoByKey = new Map(repoRows.map((r) => [r.key, r]));

  for (const [key, nRow] of notionByKey) {
    const rRow = repoByKey.get(key);
    if (!rRow) {
      lines.push(`  [${name}] "${key}" — in Notion only (no matching repo row)`);
      continue;
    }
    for (const [label, nField, rField, compare] of fields) {
      const nVal = nRow[nField];
      const rVal = rRow[rField];
      const cmp = compare ?? ((a, b) => a === b);
      if (!cmp(nVal, rVal)) {
        lines.push(`  [${name}] "${key}" ${label}: Notion="${nVal}" repo="${rVal}"`);
      }
    }
  }
  for (const [key] of repoByKey) {
    if (!notionByKey.has(key)) {
      lines.push(`  [${name}] "${key}" — in repo only (no matching Notion row)`);
    }
  }
  return lines;
}

const report = [];
let totalMismatches = 0;
function section(title, lines) {
  report.push(`\n## ${title} (${lines.length} finding${lines.length === 1 ? "" : "s"})`);
  if (lines.length === 0) report.push("  clean");
  else report.push(...lines);
  totalMismatches += lines.length;
}

// ---- Artefacts: Name / Rarity / STATUS / Notes vs Effect -----------------
section(
  "Artefacts",
  diffCatalog(
    "artefacts",
    (snapshot.artefacts ?? []).map((r) => ({ key: normName(r.Name), rarity: r.Rarity, status: r.STATUS, notes: r.Notes })),
    artefactsJs.map((a) => ({ key: normName(a.name), rarity: a.rarity, status: a.status, effect: a.effect })),
    [
      ["Rarity", "rarity", "rarity"],
      ["STATUS", "status", "status"],
      ["Effect", "notes", "effect", (a, b) => coreText(a) === coreText(b)],
    ]
  )
);

// ---- Items: Name / Tier / Description --------------------------------
section(
  "Items",
  diffCatalog(
    "items",
    (snapshot.items ?? []).map((r) => ({ key: normName(r.Name), tier: r.Tier, description: r.Description })),
    itemsArr.map((i) => ({ key: normName(i.name), tier: i.tier, description: i.description })),
    [
      ["Tier", "tier", "tier"],
      ["Description", "description", "description", (a, b) => coreText(a) === coreText(b)],
    ]
  )
);

// ---- Pieces: Codex ID -> Name / Betza / Letter -----------------------
section(
  "Pieces",
  diffCatalog(
    "pieces",
    (snapshot.pieces ?? []).map((r) => ({ key: r["Codex ID"], name: r.Name, betza: r.Betza, letter: r.Letter })),
    piecesJs.map((p) => ({ key: p.id, name: p.name, betza: p.betza, letter: p.letter || p.glyph })),
    [
      ["Name", "name", "name", (a, b) => normName(a) === normName(b)],
      ["Betza", "betza", "betza"],
      ["Letter", "letter", "letter"],
    ]
  )
);

// ---- Tariffs: Name / Tier / Description -------------------------------
section(
  "Tariffs",
  diffCatalog(
    "tariffs",
    (snapshot.tariffs ?? [])
      .filter((r) => r.Name != null)
      .map((r) => ({ key: normName(r.Name), tier: r.Tier, description: r.Description })),
    tariffsArr.map((t) => ({ key: normName(t.name), tier: t.tier, description: t.description })),
    [
      ["Tier", "tier", "tier"],
      ["Description", "description", "description", (a, b) => coreText(a) === coreText(b)],
    ]
  )
);

console.log(`Notion drift report — snapshot fetched ${snapshot.fetchedAt ?? "(no timestamp in snapshot)"}`);
console.log(report.join("\n"));
console.log(`\n${totalMismatches} total finding${totalMismatches === 1 ? "" : "s"} across 4 catalogs.`);
console.log(
  totalMismatches === 0
    ? "Clean — repo matches the Notion snapshot."
    : "Report only: nothing was written. Read each finding and decide, case by case, which side is stale."
);
