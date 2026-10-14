---
name: quality-review
description: コード・スキル・ツールの品質評価やスコアリングを頼まれたとき（review・evaluation・assessment、GAFA 6 軸・8 軸）。採点前の必須手順、検証プロトコル VP-1〜5、8 軸の出典
---

# Quality Review Standard

> Full rubric and protocol: `~/.claude/bochi-data/master-quality-review.md`

## When to Apply

- **code-reviewer** agent evaluates any code
- GAFA 6-axis or 8-axis quality scoring is requested
- Any skill, tool, or project receives a quality evaluation
- User asks for a "review", "evaluation", or "assessment"

## Mandatory Review Prerequisites (HARD-GATE)

Before scoring ANY item, the reviewer MUST:

```
[ ] PR-1: READ every line of target code (all source files, not summaries)
[ ] PR-2: READ every line of README.md / README.en.md
[ ] PR-3: RUN or verify test output
[ ] PR-4: VERIFY all internal references resolve
```

Skipping these steps invalidates the review. "Rubber stamp" reviews are prohibited.

## Evaluation Protocol

1. **VP-1**: Independent count verification — verify test count, line count, and coverage with grep/wc/execution output, not subagent reports or estimates
2. **VP-2**: Blind re-evaluation — score every item BEFORE viewing prior scores, then compare and document the delta reasons
3. **VP-3**: Full rubric pass/fail — judge all items after improvements, not just changed ones. Partial score estimation is prohibited; only measured values are valid
4. **VP-4**: Evidence gate — each score needs a code ref, test output, or metric
5. **VP-5**: Calibration check — flag <2% delta without documented changes

| Anti-pattern | Signal | Prevention |
|---|---|---|
| Optimistic Estimate Bias | "This should add +X points" | Full rubric re-evaluation |
| Subagent Count Inflation | Agent numbers differ from grep | Independent verification |
| Score Anchoring | Re-eval score suspiciously close to last | Blind evaluation first |

## Quick Reference: 8 Axes

| # | Axis | Source |
|---|------|--------|
| 1 | Design & Architecture | ISO 25010: Maintainability |
| 2 | Functionality & Correctness | ISO 25010: Functional Suitability |
| 3 | Complexity & Readability | Google eng-practices |
| 4 | Testing & Reliability | ISO 25010 + CISQ |
| 5 | Security | ISO 25010 + CISQ |
| 6 | Documentation & Usability | ISO 25010: Usability |
| 7 | Performance & Efficiency | ISO 25010: Performance Efficiency |
| 8 | Automation & Self-Improvement | forge_ace + DORA 2025 |

For full scoring criteria, evidence requirements, and anti-pattern watchlist:
**Load**: `~/.claude/bochi-data/master-quality-review.md`
