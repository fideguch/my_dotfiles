# Quality Review Standard — Global Rule

> Cross-cutting review rule ensuring all code evaluations follow world-class standards.
> Full rubric and protocol: `~/.claude/bochi-data/master-quality-review.md`

## When to Apply

This rule applies when:
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

## Evaluation Protocol (Summary)

1. **VP-1**: Independent count verification (grep/wc, not subagent trust)
2. **VP-2**: Blind re-evaluation (score before viewing prior scores)
3. **VP-3**: Full rubric pass/fail (all items, not just changed ones)
4. **VP-4**: Evidence gate (each score needs code ref, test output, or metric)
5. **VP-5**: Calibration check (flag <2% delta without documented changes)

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

> **Language note**: This rule applies universally across all languages and project types.
