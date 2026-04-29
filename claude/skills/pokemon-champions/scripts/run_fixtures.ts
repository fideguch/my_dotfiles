// Phase 2 verification: run all 10 fixtures against bin/pokechamp-calc and
// produce a pass/fail report + T1 latency benchmark (cold + warm).
//
// Usage:
//   bun scripts/run_fixtures.ts
//
// Exit code: 0 = all pass, 1 = any fail.

import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

interface Expect {
  percent_min_at_least?: number;
  percent_max_at_most?: number;
  ko_chance_n_at_most?: number;
  describe_must_include?: string;
}
interface Fixture {
  id: string;
  label: string;
  input: Record<string, unknown>;
  expect: Expect;
}
interface FixturesFile {
  fixtures: Fixture[];
}

const ROOT = resolve(import.meta.dir, "..");
const BIN = resolve(ROOT, "bin", "pokechamp-calc");
const FIXTURES_PATH = resolve(ROOT, "tests", "calc_fixtures.json");

const fixtures = (JSON.parse(readFileSync(FIXTURES_PATH, "utf-8")) as FixturesFile).fixtures;

function runOnce(input: Record<string, unknown>): {
  ok: boolean;
  result: Record<string, unknown>;
  wallMs: number;
} {
  const t0 = performance.now();
  const proc = spawnSync(BIN, [], {
    input: JSON.stringify(input),
    encoding: "utf-8",
  });
  const wallMs = performance.now() - t0;
  if (proc.status !== 0) {
    return {
      ok: false,
      result: { error: proc.stderr || "non-zero exit", stdout: proc.stdout },
      wallMs,
    };
  }
  return { ok: true, result: JSON.parse(proc.stdout) as Record<string, unknown>, wallMs };
}

const report: Array<Record<string, unknown>> = [];
let passed = 0;
let failed = 0;

console.log("=".repeat(60));
console.log("Phase 2: 10-fixture regression + T1 latency benchmark");
console.log("=".repeat(60));

for (const fx of fixtures) {
  const { ok, result, wallMs } = runOnce(fx.input);
  if (!ok) {
    console.log(`[FAIL] ${fx.id} — process error`);
    console.log(JSON.stringify(result, null, 2));
    failed++;
    report.push({ id: fx.id, status: "FAIL", reason: "process_error", result, wallMs });
    continue;
  }
  const pmin = (result.percent_min as number) ?? -1;
  const pmax = (result.percent_max as number) ?? -1;
  const koN = ((result.ko_chance as Record<string, unknown> | undefined)?.n as number) ?? -1;
  const desc = (result.desc as string) ?? "";

  const e = fx.expect;
  let ok2 = true;
  const reasons: string[] = [];
  if (e.percent_min_at_least !== undefined && pmin < e.percent_min_at_least) {
    ok2 = false;
    reasons.push(`percent_min ${pmin} < ${e.percent_min_at_least}`);
  }
  if (e.percent_max_at_most !== undefined && pmax > e.percent_max_at_most) {
    ok2 = false;
    reasons.push(`percent_max ${pmax} > ${e.percent_max_at_most}`);
  }
  if (e.ko_chance_n_at_most !== undefined && koN >= 0 && koN > e.ko_chance_n_at_most) {
    ok2 = false;
    reasons.push(`ko_chance.n ${koN} > ${e.ko_chance_n_at_most}`);
  }
  if (e.describe_must_include && !desc.includes(e.describe_must_include)) {
    ok2 = false;
    reasons.push(`desc missing '${e.describe_must_include}'`);
  }

  const tag = ok2 ? "PASS" : "FAIL";
  console.log(`[${tag}] ${fx.id} — ${pmin}-${pmax}% (${wallMs.toFixed(0)}ms wall) ${fx.label}`);
  if (!ok2) {
    console.log(`        reasons: ${reasons.join("; ")}`);
    console.log(`        desc: ${desc}`);
  }
  if (ok2) passed++; else failed++;
  report.push({
    id: fx.id,
    status: tag,
    percent_min: pmin,
    percent_max: pmax,
    ko_chance_n: koN,
    desc,
    wall_ms: +wallMs.toFixed(2),
    elapsed_ms_internal: result.elapsed_ms,
    reasons,
  });
}

// Latency benchmark: 10 sequential calls of fixture #1 (warm cache after first).
console.log("");
console.log("=".repeat(60));
console.log("T1 latency benchmark (10x fixture #01)");
console.log("=".repeat(60));
const fx1 = fixtures[0];
const wallTimes: number[] = [];
for (let i = 0; i < 10; i++) {
  const { wallMs } = runOnce(fx1.input);
  wallTimes.push(wallMs);
  console.log(`  run ${i + 1}: ${wallMs.toFixed(1)}ms`);
}
wallTimes.sort((a, b) => a - b);
const median = wallTimes[Math.floor(wallTimes.length / 2)];
const min = wallTimes[0];
const max = wallTimes[wallTimes.length - 1];
const mean = wallTimes.reduce((a, b) => a + b, 0) / wallTimes.length;

console.log("");
console.log(`Latency: min=${min.toFixed(1)}ms median=${median.toFixed(1)}ms mean=${mean.toFixed(1)}ms max=${max.toFixed(1)}ms`);
console.log(`T1 budget: 300ms — median ${median < 300 ? "PASS" : "FAIL"}`);

const summary = {
  generated_at: new Date().toISOString(),
  fixtures_total: fixtures.length,
  fixtures_passed: passed,
  fixtures_failed: failed,
  t1_latency: {
    samples: wallTimes,
    min_ms: +min.toFixed(2),
    median_ms: +median.toFixed(2),
    mean_ms: +mean.toFixed(2),
    max_ms: +max.toFixed(2),
    budget_ms: 300,
    budget_pass: median < 300,
  },
  fixtures_report: report,
};

writeFileSync(resolve(ROOT, "tests", "calc_fixtures_results.json"), JSON.stringify(summary, null, 2));
console.log("");
console.log(`Summary written to tests/calc_fixtures_results.json`);
console.log(`Result: ${passed}/${fixtures.length} fixtures passed, T1 median=${median.toFixed(1)}ms`);
process.exit(failed > 0 ? 1 : 0);
