# MCP Selection Guide for Analytics Tools

## General Rule

Keep total active MCP servers under 10 at any time.
Too many MCPs degrade context quality, increase latency, and cause tool-name collisions.
Enable only the MCPs your current project actually needs.

## Available Analytics MCP Servers

### 1. GA4 (Google Analytics 4) — Official

| Field | Value |
|-------|-------|
| Repo | [googleanalytics/google-analytics-mcp](https://github.com/googleanalytics/google-analytics-mcp) |
| Package | `analytics-mcp` (PyPI) |
| Runtime | Python 3.10+ via `pipx` |
| Auth | Google Application Default Credentials (ADC) |
| Access | Read-only (reports, realtime, account info) |

**Installation prerequisites:**
```bash
# 1. Install pipx (if not already installed)
brew install pipx && pipx ensurepath

# 2. Enable APIs in your Google Cloud project:
#    - Google Analytics Admin API
#    - Google Analytics Data API

# 3. Set up ADC with analytics scope
gcloud auth application-default login \
  --scopes https://www.googleapis.com/auth/analytics.readonly,https://www.googleapis.com/auth/cloud-platform \
  --client-id-file=YOUR_CLIENT_JSON_FILE
# → Copy the PATH_TO_CREDENTIALS_JSON printed to console
```

**Claude Code MCP configuration** (add to `.mcp.json` or project settings):
```json
{
  "mcpServers": {
    "analytics-mcp": {
      "command": "pipx",
      "args": ["run", "analytics-mcp"],
      "env": {
        "GOOGLE_APPLICATION_CREDENTIALS": "PATH_TO_CREDENTIALS_JSON",
        "GOOGLE_PROJECT_ID": "YOUR_PROJECT_ID"
      }
    }
  }
}
```

**Key tools:** `get_account_summaries`, `run_report`, `run_realtime_report`, `get_property_details`

---

### 2. Google Ads — Official (Google Marketing Solutions)

| Field | Value |
|-------|-------|
| Repo | [google-marketing-solutions/google_ads_mcp](https://github.com/google-marketing-solutions/google_ads_mcp) |
| Runtime | Python 3.12+ via `pipx` or `uv` |
| Auth | `google-ads.yaml` credential file |
| Access | Read campaigns, ad groups, metrics |

> Note: "This is not an officially supported Google product" per the repo disclaimer,
> but it is maintained by google-marketing-solutions org.

**Installation prerequisites:**
```bash
# 1. Install pipx
brew install pipx && pipx ensurepath

# 2. Create google-ads.yaml in your home directory with:
#    - client_id
#    - client_secret
#    - refresh_token
#    - developer_token
#    - login_customer_id (optional but recommended)
#
# Generate credentials using:
# https://github.com/googleads/google-ads-python/blob/main/examples/authentication/generate_user_credentials.py
```

**Claude Code MCP configuration:**
```json
{
  "mcpServers": {
    "google-ads-mcp": {
      "command": "pipx",
      "args": [
        "run",
        "--spec",
        "git+https://github.com/google-marketing-solutions/google_ads_mcp.git",
        "run-mcp-server"
      ],
      "env": {
        "GOOGLE_ADS_CREDENTIALS": "PATH_TO_GOOGLE_ADS_YAML"
      },
      "timeout": 30000
    }
  }
}
```

**Key tools:** List campaigns, get campaign metrics, get ad groups

---

### 3. Meta Ads (Facebook / Instagram)

| Field | Value |
|-------|-------|
| Repo | [pipeboard-co/meta-ads-mcp](https://github.com/pipeboard-co/meta-ads-mcp) (690+ stars, most popular) |
| Remote URL | `https://mcp.pipeboard.co/meta-ads-mcp` |
| Auth | Pipeboard OAuth or Meta API access token |
| Access | Campaigns, ad sets, ads, creatives, insights |

> Note: This is a community project (not official Meta). The Pipeboard remote MCP
> is the easiest option; local installation requires a Meta Developer App.

**Option A: Remote MCP (recommended — no local setup):**

For Claude Pro/Max web UI:
1. Go to claude.ai/settings/integrations
2. Add integration with URL: `https://mcp.pipeboard.co/meta-ads-mcp`
3. Connect your Facebook Ads account via OAuth

For Claude Code / Cursor (remote streamable HTTP):
```json
{
  "mcpServers": {
    "meta-ads": {
      "url": "https://mcp.pipeboard.co/meta-ads-mcp"
    }
  }
}
```

**Option B: Local installation with direct token:**
```json
{
  "mcpServers": {
    "meta-ads": {
      "url": "https://mcp.pipeboard.co/meta-ads-mcp?token=YOUR_PIPEBOARD_TOKEN"
    }
  }
}
```
Get your token at [pipeboard.co/api-tokens](https://pipeboard.co/api-tokens).

**Key tools:** `get_ad_accounts`, `get_account_info`, campaign/ad set/ad insights, creative analysis

---

### 4. BigQuery

| Field | Value |
|-------|-------|
| Repo | No official Google MCP exists yet (as of 2026-03) |
| Best option | Use GA4 MCP for analytics data, or query BigQuery via `gcloud` / SQL directly |
| Alternative | Community repos exist but none are mature (all 0-3 stars) |

> **Recommendation:** For BigQuery access, use one of these approaches instead of an immature MCP:
>
> 1. **GA4 MCP** — already connects to GA4 data (which can export to BigQuery)
> 2. **gcloud CLI** — run `bq query` commands directly via Claude Code's Bash tool
> 3. **Wait** — Google Cloud Platform has not yet released an official BigQuery MCP

If a community BigQuery MCP is needed despite the above:
```bash
# Example: peter-palmer/bigquery-mcp-server (TypeScript, minimal)
# https://github.com/peter-palmer/bigquery-mcp-server
npx bigquery-mcp-server
```

```json
{
  "mcpServers": {
    "bigquery": {
      "command": "npx",
      "args": ["bigquery-mcp-server"],
      "env": {
        "GOOGLE_APPLICATION_CREDENTIALS": "PATH_TO_CREDENTIALS_JSON",
        "GOOGLE_CLOUD_PROJECT": "YOUR_PROJECT_ID"
      }
    }
  }
}
```

---

## Project Type Recommendations

<!-- プロジェクトタイプ別の推奨MCP構成 -->

### SaaS (B2B/B2C Product)
| MCP | Priority | Reason |
|-----|----------|--------|
| GA4 | Required | User behavior, conversion funnels, retention |
| BigQuery | Optional | Deep analysis on exported GA4 data |
| Google Ads | If running | Paid acquisition metrics |
| Meta Ads | If running | Social acquisition metrics |

### Growth / Performance Marketing
| MCP | Priority | Reason |
|-----|----------|--------|
| Google Ads | Required | Core ad performance data |
| Meta Ads | Required | Social ad performance data |
| GA4 | Required | Attribution, conversion tracking |
| BigQuery | Optional | Cross-channel analysis |

### Platform / Marketplace
| MCP | Priority | Reason |
|-----|----------|--------|
| GA4 | Required | Supply/demand funnel tracking |
| Google Ads | If running | Demand-side acquisition |
| Meta Ads | If running | Demand-side acquisition |
| BigQuery | Recommended | Complex multi-sided metrics |

### Default (Early-stage / MVP)
| MCP | Priority | Reason |
|-----|----------|--------|
| GA4 | Required | Basic product analytics |
| Others | Not yet | Add when you have paid channels running |

## Credential Safety

- **NEVER** store credentials in MCP config files committed to git
- Use environment variables or credential files outside the repo
- Add credential file paths to `.gitignore`
- See [security.md](./security.md) for the full secret management policy

## Troubleshooting

| Problem | Solution |
|---------|----------|
| MCP server not starting | Check Python/Node.js version requirements |
| Auth error on GA4 | Re-run `gcloud auth application-default login` with correct scopes |
| Google Ads "no access" | Verify `google-ads.yaml` has valid `developer_token` and `refresh_token` |
| Meta Ads connection fail | Try Remote MCP first; local install requires Meta Developer App approval |
| Too many MCPs active | Disable MCPs not needed for current task; keep under 10 |
