# Quality PDCA Cycle — Global Coding Rule

> Cross-cutting quality rule derived from PM Tool Suite P6 strict evaluation (2026-03-28).
> Prevents optimistic bias, subagent count inflation, and score anchoring.

## Mandatory Verification Protocols

### VP-1: Independent Count Verification
When subagents or estimates report numerical values (test count, line count, coverage %),
verify independently with grep/wc/execution output before using in decisions.

### VP-2: Blind Re-evaluation
When re-evaluating quality after improvements, score all checklist items BEFORE
looking at previous scores. Compare afterwards and document delta reasons.

### VP-3: Full Rubric Pass/Fail Gate
After completing improvements, judge ALL checklist items (not just improved ones).
Partial score estimation is prohibited. Only measured values are valid scores.

## Anti-Patterns to Watch

| Pattern | Signal | Prevention |
|---------|--------|------------|
| Optimistic Estimate Bias | "This should add +X points" | Full rubric re-evaluation required |
| Subagent Count Inflation | Agent reports different numbers than grep | Independent verification |
| Score Anchoring | Re-eval score suspiciously close to last score | Blind evaluation first |
| Phantom Addition Fallacy | Plan says "add" for existing content | Read file before planning |
| Delegated Verification Deficit | Critical detail from subagent only | Read the file yourself |

## PDCA Application (Every Task)

1. **Plan**: Check Product Vision / JTBD before starting. Identify target rubric items.
2. **Do**: Implement within scope. Read files before modifying.
3. **Check**: Run VP-1,2,3. Execute all tests. Re-judge full rubric.
4. **Act**: Record measured scores. Analyze delta from estimates. Check for anti-patterns.

> **Language note**: This rule applies universally across all languages and project types.
