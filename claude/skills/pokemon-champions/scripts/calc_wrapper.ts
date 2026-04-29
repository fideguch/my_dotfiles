// Phase 2: Damage calc wrapper.
// Reads a single JSON request from stdin, prints a single JSON result to stdout.
// On error, exits 1 and writes a structured JSON error to stderr.
//
// Input schema (all keys optional unless marked required):
// {
//   "gen": 9,                                    // required, 1-9
//   "format": "Singles",                         // "Singles" | "Doubles", default "Singles"
//   "attacker": {
//     "name": "Garchomp",                        // required, English Showdown name
//     "level": 50,                               // default 100
//     "item": "Choice Band",
//     "ability": "Rough Skin",
//     "nature": "Jolly",
//     "evs": { "hp": 0, "atk": 252, "def": 0, "spa": 0, "spd": 0, "spe": 252 },
//     "ivs": { "hp": 31, "atk": 31, ... },
//     "boosts": { "atk": 1 },
//     "status": "brn" | "psn" | "tox" | "par" | "slp" | "frz" | "",
//     "teraType": "Ground",                      // optional
//     "isDynamaxed": true,                       // gen 8 only
//     "dynamaxLevel": 10,
//     "abilityOn": true                          // for activation-required abilities
//   },
//   "defender": { ... same shape },
//   "move": {
//     "name": "Earthquake",                      // required
//     "isCrit": false,
//     "useZ": false,
//     "useMax": false,
//     "hits": 1,                                 // for multi-hit override
//     "bp": 100                                  // override base power
//   },
//   "field": {
//     "weather": "Sun" | "Rain" | "Sand" | "Snow" | "Hail" | "Harsh Sunshine" | "Heavy Rain" | "Strong Winds",
//     "terrain": "Electric" | "Grassy" | "Misty" | "Psychic",
//     "isGravity": false,
//     "isMagicRoom": false,
//     "isWonderRoom": false,
//     "attackerSide": { "isSR": false, "isReflect": false, "isLightScreen": false, ... },
//     "defenderSide": { "isSR": true, "spikes": 0, ... }
//   }
// }
//
// Output schema:
// {
//   "ok": true,
//   "damage": [n0, n1, ..., n15],
//   "min": number, "max": number,
//   "percent_min": number, "percent_max": number,
//   "ko_chance": { "chance": number, "n": number, "text": string },
//   "desc": string,
//   "attacker_stats": StatsTable, "defender_stats": StatsTable,
//   "elapsed_ms": number
// }

import { Generations, Pokemon, Move, Field, calculate } from "@smogon/calc";

type StatsTable = { hp: number; atk: number; def: number; spa: number; spd: number; spe: number };

interface SideInput {
  isSR?: boolean;
  spikes?: number;
  isReflect?: boolean;
  isLightScreen?: boolean;
  isAuroraVeil?: boolean;
  isProtected?: boolean;
  isSeeded?: boolean;
  isFriendGuard?: boolean;
  isHelpingHand?: boolean;
  isTailwind?: boolean;
  isFlowerGift?: boolean;
  isBattery?: boolean;
  isPowerSpot?: boolean;
  isSteelySpirit?: boolean;
}

interface PokemonInput {
  name: string;
  level?: number;
  item?: string;
  ability?: string;
  nature?: string;
  evs?: Partial<StatsTable>;
  ivs?: Partial<StatsTable>;
  boosts?: Partial<Omit<StatsTable, "hp">>;
  status?: "brn" | "psn" | "tox" | "par" | "slp" | "frz" | "";
  teraType?: string;
  isDynamaxed?: boolean;
  dynamaxLevel?: number;
  abilityOn?: boolean;
  curHP?: number;
}

interface MoveInput {
  name: string;
  isCrit?: boolean;
  useZ?: boolean;
  useMax?: boolean;
  hits?: number;
  bp?: number;
  type?: string;
}

interface FieldInput {
  weather?: string;
  terrain?: string;
  isGravity?: boolean;
  isMagicRoom?: boolean;
  isWonderRoom?: boolean;
  attackerSide?: SideInput;
  defenderSide?: SideInput;
}

interface CalcInput {
  gen: number;
  format?: "Singles" | "Doubles";
  attacker: PokemonInput;
  defender: PokemonInput;
  move: MoveInput;
  field?: FieldInput;
}

function readStdin(): Promise<string> {
  return new Promise((resolve, reject) => {
    let buf = "";
    process.stdin.setEncoding("utf-8");
    process.stdin.on("data", (chunk) => (buf += chunk));
    process.stdin.on("end", () => resolve(buf));
    process.stdin.on("error", reject);
  });
}

function buildPokemon(gen: ReturnType<typeof Generations.get>, p: PokemonInput): Pokemon {
  if (!p.name) throw new Error("attacker/defender.name required");
  const opts: Record<string, unknown> = {};
  if (p.level !== undefined) opts.level = p.level;
  if (p.item) opts.item = p.item;
  if (p.ability) opts.ability = p.ability;
  if (p.nature) opts.nature = p.nature;
  if (p.evs) opts.evs = p.evs;
  if (p.ivs) opts.ivs = p.ivs;
  if (p.boosts) opts.boosts = p.boosts;
  if (p.status !== undefined) opts.status = p.status;
  if (p.teraType) opts.teraType = p.teraType;
  if (p.isDynamaxed) opts.isDynamaxed = p.isDynamaxed;
  if (p.dynamaxLevel !== undefined) opts.dynamaxLevel = p.dynamaxLevel;
  if (p.abilityOn !== undefined) opts.abilityOn = p.abilityOn;
  if (p.curHP !== undefined) opts.curHP = p.curHP;
  return new Pokemon(gen, p.name, opts);
}

function buildMove(gen: ReturnType<typeof Generations.get>, m: MoveInput): Move {
  if (!m.name) throw new Error("move.name required");
  const opts: Record<string, unknown> = {};
  if (m.isCrit !== undefined) opts.isCrit = m.isCrit;
  if (m.useZ !== undefined) opts.useZ = m.useZ;
  if (m.useMax !== undefined) opts.useMax = m.useMax;
  if (m.hits !== undefined) opts.hits = m.hits;
  if (m.bp !== undefined) opts.bp = m.bp;
  if (m.type) opts.type = m.type;
  return new Move(gen, m.name, opts);
}

function buildField(f: FieldInput | undefined): Field {
  if (!f) return new Field();
  const opts: Record<string, unknown> = {};
  if (f.weather) opts.weather = f.weather;
  if (f.terrain) opts.terrain = f.terrain;
  if (f.isGravity) opts.isGravity = f.isGravity;
  if (f.isMagicRoom) opts.isMagicRoom = f.isMagicRoom;
  if (f.isWonderRoom) opts.isWonderRoom = f.isWonderRoom;
  if (f.attackerSide) opts.attackerSide = f.attackerSide;
  if (f.defenderSide) opts.defenderSide = f.defenderSide;
  return new Field(opts);
}

function summarize(input: CalcInput): Record<string, unknown> {
  const t0 = performance.now();
  const gens = Generations.get(input.gen);

  const attacker = buildPokemon(gens, input.attacker);
  const defender = buildPokemon(gens, input.defender);
  const move = buildMove(gens, input.move);
  const field = buildField(input.field);

  const result = calculate(gens, attacker, defender, move, field);

  // damage may be number, number[], or array of arrays for multi-hit.
  // Normalize to flat number[].
  let damage: number[] = [];
  const raw = result.damage as number | number[] | number[][];
  if (Array.isArray(raw)) {
    if (raw.length > 0 && Array.isArray(raw[0])) {
      // multi-hit -> use last (post-hits cumulative is not given; flatten and report
      // each hit's roll set so caller can interpret).
      damage = (raw as number[][]).flat();
    } else {
      damage = raw as number[];
    }
  } else if (typeof raw === "number") {
    damage = [raw];
  }

  const hp = defender.maxHP();
  const min = damage.length > 0 ? Math.min(...damage) : 0;
  const max = damage.length > 0 ? Math.max(...damage) : 0;
  const percentMin = hp > 0 ? +((min / hp) * 100).toFixed(1) : 0;
  const percentMax = hp > 0 ? +((max / hp) * 100).toFixed(1) : 0;

  const ko = result.kochance ? result.kochance() : { chance: 0, n: 0, text: "" };
  const desc = result.fullDesc ? result.fullDesc() : "";
  const elapsedMs = +(performance.now() - t0).toFixed(2);

  return {
    ok: true,
    damage,
    min,
    max,
    percent_min: percentMin,
    percent_max: percentMax,
    defender_max_hp: hp,
    ko_chance: ko,
    desc,
    attacker_stats: attacker.stats,
    defender_stats: defender.stats,
    elapsed_ms: elapsedMs,
  };
}

async function main() {
  const raw = await readStdin();
  const input = JSON.parse(raw) as CalcInput;
  const result = summarize(input);
  process.stdout.write(JSON.stringify(result));
  process.exit(0);
}

main().catch((err: Error) => {
  const errOut = {
    ok: false,
    error: err.message,
    stack: err.stack,
  };
  process.stderr.write(JSON.stringify(errOut));
  process.exit(1);
});
