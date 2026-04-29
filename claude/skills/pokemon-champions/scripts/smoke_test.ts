// Phase 0 smoke test: verify Bun + @smogon/calc can produce a damage calculation.
// Runs a known scenario from Showdown research:
//   Choice Band Garchomp Earthquake vs. 4 HP Mimikyu (after Disguise consumed)
// Expected: roughly 88-105% (high roll 1HKO).

import { Generations, Pokemon, Move, calculate } from "@smogon/calc";

const gens = Generations.get(9);

const attacker = new Pokemon(gens, "Garchomp", {
  item: "Choice Band",
  nature: "Jolly",
  evs: { atk: 252, spe: 252 },
  ability: "Rough Skin",
});

const defender = new Pokemon(gens, "Mimikyu", {
  evs: { hp: 4 },
  nature: "Jolly",
  ability: "Disguise",
});

const move = new Move(gens, "Earthquake");

const result = calculate(gens, attacker, defender, move);

const hp = defender.maxHP();
const min = result.damage[0] ?? result.range()[0];
const max = result.damage[result.damage.length - 1] ?? result.range()[1];
const pctMin = ((min as number) / hp * 100).toFixed(1);
const pctMax = ((max as number) / hp * 100).toFixed(1);

console.log(JSON.stringify({
  attacker: attacker.name,
  attacker_item: attacker.item,
  defender: defender.name,
  move: move.name,
  damage_rolls: result.damage,
  damage_min: min,
  damage_max: max,
  defender_max_hp: hp,
  percent_min: pctMin,
  percent_max: pctMax,
  desc: result.fullDesc(),
}, null, 2));
