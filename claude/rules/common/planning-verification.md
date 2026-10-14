# Planning Verification

Applies to every plan or change that touches existing files (code, config, docs).

- Read each target before planning. Label every step CREATE / MODIFY / NOOP; a CREATE needs grep/glob proof that the target is absent
- Verify any detail that drives the change (counts, file contents, existence) yourself with Read/grep/wc. Never act on a subagent's or an estimate's number alone
- Anchor references on surrounding content, not on line numbers seen earlier in the session
- A prompt or README describing a feature is not proof it exists. Confirm in code or by running it

| Anti-pattern | Signal | Prevention |
|---|---|---|
| Phantom Addition Fallacy | Plan "adds" something that already exists | Read first, prove absence |
| Delegated Verification Deficit | A critical detail comes only from a subagent | Read the file yourself |
| Stale Context Divergence | Plan cites line numbers from earlier | Use content anchors |
| Creation-Modification Misclassification | "Add section X" when X exists | Label CREATE / MODIFY |
| Optimistic Estimate Bias | "This should add +X points" | Re-measure instead of estimating |
