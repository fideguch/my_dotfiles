# Claude Code External Skills Install Guide

New PC setup after running `set_up.sh`.
This file lists skills NOT managed by dotfiles or self-made repos.

## 1. Official Plugins

```bash
# Claude Code CLI で以下を実行
# skill-creator (Anthropic official)
claude plugins install skill-creator@claude-plugins-official

# Discord plugin
claude plugins install discord@claude-plugins-official
```

## 2. ECC (Everything Claude Code)

ECC由来スキル（50+個）は dotfiles の symlink で自動適用される。
再インストールが必要な場合:

```bash
# /configure-ecc を実行するか、以下を手動実行
npx ecc install --language typescript
```

Source: `affaan-m/everything-claude-code` (v1.9.0)

## 3. External Skills via npx skills

`~/.agents/` ディレクトリに install される。`~/.claude/skills/` へ自動 symlink 作成。

### PM Skills (45+ skills)

Source: `deanpeters/product-manager-prompts`（大部分）+ Anthropic skills

```bash
npx skills add deanpeters/product-manager-prompts
```

含まれるスキル:
- pm-user-story, pm-jobs-to-be-done, pm-prd-development, pm-positioning-statement
- pm-epic-hypothesis, pm-acquisition-channel-advisor, pm-ai-shaped-readiness-advisor
- pm-altitude-horizon-framework, pm-business-health-diagnostic, pm-company-research
- pm-context-engineering-advisor, pm-customer-journey-map, pm-customer-journey-mapping-workshop
- pm-director-readiness-advisor, pm-discovery-interview-prep, pm-discovery-process
- pm-eol-message, pm-epic-breakdown-advisor, pm-executive-onboarding-playbook
- pm-feature-investment-advisor, pm-finance-based-pricing-advisor, pm-finance-metrics-quickref
- pm-lean-ux-canvas, pm-opportunity-solution-tree, pm-pestel-analysis
- pm-pol-probe, pm-pol-probe-advisor, pm-positioning-workshop, pm-press-release
- pm-prioritization-advisor, pm-problem-framing-canvas, pm-problem-statement
- pm-product-strategy-session, pm-proto-persona, pm-recommendation-canvas
- pm-roadmap-planning, pm-saas-economics-efficiency-metrics, pm-saas-revenue-growth-metrics
- pm-skill-authoring-workflow, pm-storyboard, pm-tam-sam-som-calculator
- pm-user-story-mapping, pm-user-story-mapping-workshop, pm-user-story-splitting
- pm-vp-cpo-readiness-advisor, pm-workshop-facilitation

### Individual Skills (from .skill-lock.json)

```bash
# Vercel Labs
npx skills add vercel-labs/skills              # find-skills
npx skills add vercel-labs/agent-skills        # web-design-guidelines, vercel-react-best-practices

# Anthropic
npx skills add anthropics/skills               # frontend-design

# Other
npx skills add kimny1143/claude-code-template  # ui-ux-pro-max
npx skills add remotion-dev/skills             # remotion-best-practices
npx skills add aj-geddes/useful-ai-prompts     # funnel-analysis
npx skills add wondelai/skills                 # cro-methodology
```

### Workflow Skills (bundled with PM skills or find-skills)

以下はPMスキル or ECC install 時に同梱される:
- brainstorming, dispatching-parallel-agents, doc-coauthoring
- executing-plans, finishing-a-development-branch, receiving-code-review
- requesting-code-review, subagent-driven-development, systematic-debugging
- test-driven-development, using-git-worktrees, using-superpowers
- verification-before-completion, writing-plans, writing-skills

## 4. Self-Made Skills (GitHub repos)

`set_up.sh` が自動 clone する。手動実行が必要な場合:

```bash
# ~/.claude/skills/ 内に直接 clone
git clone git@github.com:fideguch/bochi.git ~/.claude/skills/bochi
git clone git@github.com:fideguch/pm_data_analysis.git ~/.claude/skills/pm-data-analysis
git clone git@github.com:fideguch/speckit-bridge.git ~/.claude/skills/speckit-bridge

# 別ディレクトリに clone → symlink
git clone git@github.com:fideguch/pm_ad_analysis.git ~/pm_ad_analysis
ln -s ~/pm_ad_analysis ~/.claude/skills/pm-ad-analysis

git clone git@github.com:fideguch/google-workspace.git ~/google_mcps
ln -s ~/google_mcps/google-workspace ~/.claude/skills/google-workspace

# requirements_designer は npx skills で install 後、~/.agents/skills/ 内で git init + remote add
```

## 5. Post-Install Checklist

- [ ] `settings.local.json` のプレースホルダーを実際の値に置換
- [ ] MCP サーバーの API キーを設定 (`.mcp.json` or project config)
- [ ] Discord bot token を設定 (`/discord:configure`)
- [ ] `gcloud auth application-default login` を実行 (GA4 MCP 用)
- [ ] bochi-data/ の復元 (バックアップから)
