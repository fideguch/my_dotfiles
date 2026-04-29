// Phase 1: Extract static data from pokemon-showdown clone + PokeAPI JP names.
// Outputs: data/{pokedex,moves,abilities,items,learnsets,typechart,natures,ja_names}.json
//          data/VERSION.json
//
// Usage (run from skill root):
//   SHOWDOWN_DIR=/tmp/pokemon-showdown POKEAPI_CSV_DIR=/tmp/pokeapi-csv \
//     bun scripts/extract_data.ts
//
// Source-of-truth attribution:
//   - Showdown data: https://github.com/smogon/pokemon-showdown (commit pinned in VERSION.json)
//   - JP names: https://github.com/PokeAPI/pokeapi (CSV mirror, language_id=1 = ja-hrkt)

import { execSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { join, resolve } from "node:path";
import { gzipSync } from "node:zlib";

const SHOWDOWN_DIR = process.env.SHOWDOWN_DIR ?? "/tmp/pokemon-showdown";
const POKEAPI_CSV_DIR = process.env.POKEAPI_CSV_DIR ?? "/tmp/pokeapi-csv";
const OUT_DIR = resolve(import.meta.dir, "..", "data");

if (!existsSync(SHOWDOWN_DIR)) {
  console.error(`SHOWDOWN_DIR not found: ${SHOWDOWN_DIR}`);
  process.exit(1);
}
if (!existsSync(POKEAPI_CSV_DIR)) {
  console.error(`POKEAPI_CSV_DIR not found: ${POKEAPI_CSV_DIR}`);
  process.exit(1);
}
mkdirSync(OUT_DIR, { recursive: true });

// ----------------------------------------------------------------
// 1. Showdown data (TS -> JSON)
// ----------------------------------------------------------------
async function importShowdown<T extends Record<string, unknown>>(
  filename: string,
  exportName: string,
): Promise<T> {
  const path = join(SHOWDOWN_DIR, "data", filename);
  // Bun executes TS directly; Showdown files use a sim/ type import that Bun
  // doesn't need to resolve at runtime (interface only).
  const mod = (await import(path)) as Record<string, T>;
  const data = mod[exportName];
  if (!data) {
    throw new Error(`Export '${exportName}' missing in ${filename}`);
  }
  return data;
}

console.log("[1/4] Loading Showdown TS data...");
const Pokedex = await importShowdown("pokedex.ts", "Pokedex");
const Moves = await importShowdown("moves.ts", "Moves");
const Abilities = await importShowdown("abilities.ts", "Abilities");
const Items = await importShowdown("items.ts", "Items");
const Learnsets = await importShowdown("learnsets.ts", "Learnsets");
const TypeChart = await importShowdown("typechart.ts", "TypeChart");
const Natures = await importShowdown("natures.ts", "Natures");

writeFileSync(join(OUT_DIR, "pokedex.json"), JSON.stringify(Pokedex, null, 0));
writeFileSync(join(OUT_DIR, "moves.json"), JSON.stringify(Moves, null, 0));
writeFileSync(join(OUT_DIR, "abilities.json"), JSON.stringify(Abilities, null, 0));
writeFileSync(join(OUT_DIR, "items.json"), JSON.stringify(Items, null, 0));
writeFileSync(join(OUT_DIR, "typechart.json"), JSON.stringify(TypeChart, null, 0));
writeFileSync(join(OUT_DIR, "natures.json"), JSON.stringify(Natures, null, 0));

const learnsetsJson = JSON.stringify(Learnsets, null, 0);
writeFileSync(join(OUT_DIR, "learnsets.json"), learnsetsJson);
writeFileSync(join(OUT_DIR, "learnsets.json.gz"), gzipSync(Buffer.from(learnsetsJson)));

// ----------------------------------------------------------------
// 2. PokeAPI CSV -> ja_names.json
// ----------------------------------------------------------------
console.log("[2/4] Building ja_names.json from PokeAPI CSV...");

// Tiny CSV parser: handles quoted fields, commas inside quotes, double-quote escape.
function parseCSV(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = "";
  let inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"') {
        if (text[i + 1] === '"') {
          cell += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell += c;
      }
    } else {
      if (c === '"') {
        inQuotes = true;
      } else if (c === ",") {
        row.push(cell);
        cell = "";
      } else if (c === "\n") {
        row.push(cell);
        rows.push(row);
        row = [];
        cell = "";
      } else if (c === "\r") {
        // skip
      } else {
        cell += c;
      }
    }
  }
  if (cell.length > 0 || row.length > 0) {
    row.push(cell);
    rows.push(row);
  }
  return rows;
}

function loadCSV(name: string): { header: string[]; rows: string[][] } {
  const text = readFileSync(join(POKEAPI_CSV_DIR, name), "utf-8");
  const all = parseCSV(text).filter((r) => r.length > 1 || (r.length === 1 && r[0] !== ""));
  return { header: all[0] ?? [], rows: all.slice(1) };
}

const JP_LANG_ID = "1"; // ja-hrkt
const EN_LANG_ID = "9";

// Build identifier maps (PokeAPI id -> identifier-string e.g. "bulbasaur")
function buildIdMap(csv: { header: string[]; rows: string[][] }, idCol = "id", idfCol = "identifier") {
  const idIdx = csv.header.indexOf(idCol);
  const idfIdx = csv.header.indexOf(idfCol);
  const map: Record<string, string> = {};
  for (const row of csv.rows) {
    map[row[idIdx]] = row[idfIdx];
  }
  return map;
}

const speciesIds = buildIdMap(loadCSV("pokemon_species.csv"));
const moveIds = buildIdMap(loadCSV("moves.csv"));
const abilityIds = buildIdMap(loadCSV("abilities.csv"));
const itemIds = buildIdMap(loadCSV("items.csv"));
const typeIds = buildIdMap(loadCSV("types.csv"));

// Showdown internal ID convention: lowercased, alphanumeric only.
function toShowdownId(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]/g, "");
}

// PokeAPI identifier -> Showdown key.
// PokeAPI identifiers use kebab-case: "ho-oh", "mr-mime", "tapu-koko".
// Showdown uses concatenated lowercase: "hooh", "mrmime", "tapukoko".
function pokeapiIdToShowdownKey(identifier: string): string {
  return identifier.replace(/-/g, "");
}

function buildNameMap(
  csvName: string,
  idCol: string,
  idMap: Record<string, string>,
): Record<string, string> {
  const csv = loadCSV(csvName);
  const idIdx = csv.header.indexOf(idCol);
  const langIdx = csv.header.indexOf("local_language_id");
  const nameIdx = csv.header.indexOf("name");
  const map: Record<string, string> = {};
  for (const row of csv.rows) {
    if (row[langIdx] !== JP_LANG_ID) continue;
    const identifier = idMap[row[idIdx]];
    if (!identifier) continue;
    const key = pokeapiIdToShowdownKey(identifier);
    map[key] = row[nameIdx];
  }
  return map;
}

const speciesJpById = buildNameMap("pokemon_species_names.csv", "pokemon_species_id", speciesIds);
const moveJpById = buildNameMap("move_names.csv", "move_id", moveIds);
const abilityJpById = buildNameMap("ability_names.csv", "ability_id", abilityIds);
const itemJpById = buildNameMap("item_names.csv", "item_id", itemIds);
const typeJpById = buildNameMap("type_names.csv", "type_id", typeIds);

// Build reverse maps (jp -> showdown_key) for resolver lookups.
function reverse(map: Record<string, string>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(map)) out[v] = k;
  return out;
}

// Cross-walk Showdown forms (e.g. "venusaurmega") to base species jp name.
// We index every Showdown key; if no PokeAPI match, fall back to base species
// jp name + a simple suffix translation table for forms.
const FORM_SUFFIX_JP: Record<string, string> = {
  mega: "(メガ)",
  megax: "(メガX)",
  megay: "(メガY)",
  alola: "(アローラ)",
  galar: "(ガラル)",
  hisui: "(ヒスイ)",
  paldea: "(パルデア)",
  primal: "(ゲンシ)",
  origin: "(オリジン)",
  therian: "(れいじゅう)",
  incarnate: "(けしん)",
  gmax: "(キョダイ)",
  totem: "(オヤブン)",
  paldeacombat: "(パルデア・コンバット)",
  paldeablaze: "(パルデア・ブレイズ)",
  paldeaaqua: "(パルデア・アクア)",
};

const speciesJp: Record<string, string> = { ...speciesJpById };
let formMatched = 0;
let formMissed = 0;
for (const key of Object.keys(Pokedex)) {
  if (speciesJp[key]) continue;
  // Try to find a base species by progressive suffix stripping
  const matched = Object.keys(FORM_SUFFIX_JP).find((suf) => key.endsWith(suf));
  if (matched) {
    const baseKey = key.slice(0, -matched.length);
    const baseJp = speciesJpById[baseKey];
    if (baseJp) {
      speciesJp[key] = baseJp + FORM_SUFFIX_JP[matched];
      formMatched++;
      continue;
    }
  }
  formMissed++;
}

// Final ja_names.json structure
const jaNames = {
  pokemon: {
    by_id: speciesJp,
    jp_to_id: reverse(speciesJp),
  },
  moves: {
    by_id: moveJpById,
    jp_to_id: reverse(moveJpById),
  },
  abilities: {
    by_id: abilityJpById,
    jp_to_id: reverse(abilityJpById),
  },
  items: {
    by_id: itemJpById,
    jp_to_id: reverse(itemJpById),
  },
  types: {
    by_id: typeJpById,
    jp_to_id: reverse(typeJpById),
  },
};

writeFileSync(join(OUT_DIR, "ja_names.json"), JSON.stringify(jaNames, null, 0));

// ----------------------------------------------------------------
// 3. VERSION.json
// ----------------------------------------------------------------
console.log("[3/4] Writing VERSION.json...");
const showdownSha = execSync("git rev-parse HEAD", { cwd: SHOWDOWN_DIR }).toString().trim();
const showdownDate = execSync("git log -1 --format=%cI", { cwd: SHOWDOWN_DIR }).toString().trim();

// @smogon/calc version from local lockfile
const lockfile = JSON.parse(
  readFileSync(join(import.meta.dir, "package.json"), "utf-8"),
) as { dependencies?: Record<string, string> };
const smogonCalcVersion = (lockfile.dependencies ?? {})["@smogon/calc"] ?? "unknown";

const counts = {
  pokemon: Object.keys(Pokedex).length,
  moves: Object.keys(Moves).length,
  abilities: Object.keys(Abilities).length,
  items: Object.keys(Items).length,
  learnsets: Object.keys(Learnsets).length,
  natures: Object.keys(Natures).length,
  ja_names_pokemon: Object.keys(speciesJp).length,
  ja_names_moves: Object.keys(moveJpById).length,
  ja_names_abilities: Object.keys(abilityJpById).length,
  ja_names_items: Object.keys(itemJpById).length,
  ja_names_types: Object.keys(typeJpById).length,
  jp_form_matched: formMatched,
  jp_form_missed: formMissed,
};

const version = {
  showdown_commit: showdownSha,
  showdown_commit_date: showdownDate,
  showdown_repo: "https://github.com/smogon/pokemon-showdown",
  smogon_calc_version: smogonCalcVersion,
  pokeapi_csv_source: "https://github.com/PokeAPI/pokeapi/tree/master/data/v2/csv",
  pokeapi_jp_lang_id: JP_LANG_ID,
  generated_at: new Date().toISOString(),
  counts,
};
writeFileSync(join(OUT_DIR, "VERSION.json"), JSON.stringify(version, null, 2));

// ----------------------------------------------------------------
// 4. Summary
// ----------------------------------------------------------------
console.log("[4/4] Done.");
console.log(JSON.stringify({ counts, showdown_commit: showdownSha }, null, 2));
