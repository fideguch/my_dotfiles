# AI-Generated Code Defect Scan Checklist

> Guardian Phase 2.5 — extracted for reusability and readability.
> AI-generated code has specific failure modes (2.74x security vulnerabilities,
> 1.7x quality problems — CodeRabbit 2025). Check for ALL of these.

## 2.5a. Phantom Dependency Check
- List ALL new imports/requires added
- For each: verify the package EXISTS in package.json / lock file / manifest
- For each imported symbol: Grep the package source to verify the method EXISTS
- Flag: non-existent packages, hallucinated API methods, wrong import paths
- "Package exists" is not enough — "method exists in package" is required

## 2.5b. Precondition Independence Check (Anti-Pattern #7)
- Scan Writer's test list for patterns: "(with ...)", "(assuming ...)", "(after ...)"
- Each detected precondition MUST be an independent test
- If preconditions are embedded in test descriptions → REJECT
- Precondition FAIL → dependent tests SKIP (not PASS)

## 2.5c. API Freshness Check
- Are any APIs used that are deprecated in the project's current dependency versions?
- Check version pins in manifest vs. API usage patterns
- Flag: patterns from older major versions, removed APIs, renamed methods

## 2.5d. Over-Engineering Check
- Count abstraction layers added vs. what the requirement actually needs
- Interfaces with only one implementation → flag as suspicious
- Factory/Builder/Strategy patterns with only one variant → flag
- Rule: unnecessary abstraction is a maintenance liability, not a virtue

## 2.5e. Security Vulnerability Scan (OWASP + AI-specific)
- [ ] String interpolation/concatenation in SQL queries → must use parameterized
- [ ] User input passed to eval/Function/exec/child_process → reject
- [ ] Hardcoded secrets, API keys, tokens, passwords in source → reject
- [ ] Error messages exposing internal paths, stack traces, system info → flag
- [ ] Missing input validation on new API endpoints/handlers → flag
- [ ] CORS configuration changes (especially wildcard origins) → flag
- [ ] Authentication/authorization bypass potential → flag
- [ ] Insecure deserialization (untrusted input without schema validation) → flag
- [ ] Missing rate limiting on new endpoints → flag
- [ ] Prototype pollution vectors (object spread from user input) → flag
