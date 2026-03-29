# Planning Verification — Pre-Implementation Gate

> Prevent incorrect implementations by verifying assumptions before writing code.
> Derived from 4 named anti-patterns discovered in production planning sessions.

## When to Apply

This rule applies **every time** you create an implementation plan that touches existing files. It is most critical when:
- Planning changes to 3+ files
- Subagent exploration results inform the plan
- Line numbers or file contents are referenced in the plan

## The 4 Anti-Patterns

| Anti-Pattern | Named Pattern | Signal | Prevention |
|---|---|---|---|
| Assuming something doesn't exist | **Phantom Addition Fallacy** | Plan says "add" or "create" for something in an existing file | Grep/Read the file first. Prove absence before planning creation. |
| Trusting subagent output without checking | **Delegated Verification Deficit** | Plan references subagent findings for critical details (line numbers, file content) | Read the actual file yourself for any detail that affects the implementation. |
| Using stale line numbers | **Stale Context Divergence** | Plan references specific line numbers from earlier in the session | Use content-based references ("the section starting with X"), not line numbers. |
| Confusing "add" with "enhance" | **Creation-Modification Misclassification** | Plan says "add section X" when section X already exists | Label each step CREATE or MODIFY. For CREATE, prove the target doesn't exist. |

## Pre-Planning Checklist (MANDATORY for plans touching 3+ files)

```
[ ] 1. CURRENT STATE: Read each target file before writing the plan
[ ] 2. ACTION LABEL: Each step is labeled CREATE / MODIFY / NOOP
[ ] 3. ABSENCE PROOF: Every CREATE step has grep/glob evidence of non-existence
[ ] 4. INDEPENDENT VERIFY: Subagent results for critical details verified by direct Read
[ ] 5. CONTENT REFERENCE: No bare line numbers — use surrounding content as anchor
[ ] 6. ADD vs ENHANCE: Every "add" is confirmed as truly new, not enhancement of existing
```

## How to Apply

**Before writing a plan step**, ask:

1. "Does the target file/section already exist?" → **Read it**
2. "Am I creating or modifying?" → **Label it**
3. "Where did I get this information?" → **If subagent, verify independently**
4. "Am I referencing a line number?" → **Replace with content anchor**

**Language note**: This rule applies universally across all languages and project types.
