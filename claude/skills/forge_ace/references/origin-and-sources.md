# forge_ace — Origin & Sources

## Mission

Prevent the gap between "code works" and "the right thing was built" by adding PM-Admin (requirements quality) and Designer (UI/UX quality) to the proven Writer/Guardian/Overseer pipeline.

## Origin

- **triple-agent-coding v2.0**: 3-agent code quality gate (Writer/Guardian/Overseer)
- **Amazon 90-day reset (2026-03)**: 630M order loss from AI code without safeguards
- **bochi-data 15 lessons**: Spec-as-Done Illusion, Delegated Verification Deficit, etc.
- **12 research sources**: Anthropic, Addy Osmani (Google), Microsoft Azure, CodeRabbit, Baymard, DORA 2025

## Research Sources

| # | Source | Applied To |
|---|--------|-----------|
| 1 | Anthropic Multi-Agent Research | Model selection, parallelization |
| 2 | Addy Osmani (Google Chrome) | 3-5 agent optimal, worktree isolation |
| 3 | Microsoft Azure AI Orchestration | Sequential + Maker-Checker pattern |
| 4 | Amazon 90-day Code Reset (2026-03) | Guardian Tier-1 thinking |
| 5 | Glen Rhodes Blast Radius | Review load increase, VP-1 |
| 6 | Propel Code Guardrails | 3-tier risk routing |
| 7 | CodeRabbit 2025 | AI code 2.74x vulnerabilities |
| 8 | Baymard Institute UX | 207 heuristics -> 25 items |
| 9 | Deloitte Decision AI | Quality checkpoints, audit trail |
| 10 | Prompt Engineering 2026 | XML tags +23%, thinking -40% hallucination |
| 11 | DORA 2025 Report | AI review +42-48% bug detection |
| 12 | Kinde Spec Drift | Behavioral drift != data drift |

## Token Usage Estimates

| Tier | Agents | Input Tokens | Output Tokens | Est. Cost | Est. Time |
|------|--------|-------------|--------------|-----------|-----------|
| Standard | Writer + Guardian + Overseer-std + PM-Admin-std | 20K-35K | 10K-18K | ~$1-3 | ~8-12 min |
| Full | + Designer | 30K-50K | 15K-25K | ~$3-8 | ~15-25 min |

## Troubleshooting

**GUARDIAN_ESCALATE (Round 3 deadlock):**
1. **Communication gap** -> Rewrite the requirement more precisely, re-dispatch Writer
2. **Architectural issue** -> The change is too large; split it
3. **Scope too large** -> Break into smaller change-sets and run forge_ace on each

**Designer cannot capture screenshots:**
- Playwright not installed -> Designer uses Manual Screenshot Fallback (Phase 0c)
- User provides screenshots at `/tmp/forge_ace_screen_*.png`
- Designer proceeds with QA checklist on manually provided images
