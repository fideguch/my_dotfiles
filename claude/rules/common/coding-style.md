---
paths:
  - "**/*.{ts,tsx,js,jsx,mjs,cjs,py,go,rs,java,kt,kts,swift,php,rb,c,cc,cpp,h,hpp,cs,sh,sql}"
---

# Coding Style

- Immutability: return new objects; never mutate inputs in place (language rules may override, e.g. Go)
- Files 200-400 lines typical, 800 max. Functions under 50 lines, nesting 4 levels max. Organize by feature/domain, not by type
- Handle errors explicitly at every level; never swallow them silently
- Validate external input (user input, API responses, file content) at system boundaries, schema-based where available; fail fast
- No hardcoded values: use constants or config
- Data access goes behind a repository interface. API responses use one envelope: success flag, data, error, pagination meta
