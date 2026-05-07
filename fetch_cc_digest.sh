#!/usr/bin/env bash
# =============================================================================
# fetch_cc_digest.sh
# Daily Claude Code / Agent / Subagent / Skills GitHub Digest
# Usage:  ./fetch_cc_digest.sh [GITHUB_TOKEN]
#         or set GH_TOKEN env var
# Output: digest_YYYY-MM-DD.md  (in the same directory as this script)
# =============================================================================

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATE="$(date +%Y-%m-%d)"
OUTPUT_FILE="${SCRIPT_DIR}/digest_${DATE}.md"
TOKEN="${GH_TOKEN:-${1:-}}"
AUTH_HEADER=""
[[ -n "$TOKEN" ]] && AUTH_HEADER="Authorization: Bearer ${TOKEN}"

# Search terms specifically targeting Claude Code agent ecosystem
QUERIES=(
  "claude-code agent"
  "claude subagent agent-sdk"
  "anthropic agent skill"
  "claude code hooks mcp"
  "claude agent team orchestration"
  "anthropic claude-code cli"
)

# ── Helpers ───────────────────────────────────────────────────────────────────
gh_search() {
  local query="$1"
  local encoded_q
  encoded_q="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$query")"
  local url="https://api.github.com/search/repositories?q=${encoded_q}+pushed:>$(date -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d)&sort=stars&order=desc&per_page=5"

  if [[ -n "$AUTH_HEADER" ]]; then
    curl -fsSL -H "$AUTH_HEADER" -H "Accept: application/vnd.github+json" "$url" 2>/dev/null
  else
    curl -fsSL -H "Accept: application/vnd.github+json" "$url" 2>/dev/null
  fi
}

gh_trending() {
  # GitHub trending page scrape (no auth needed) via API proxy search
  local since_date
  since_date="$(date -d '1 day ago' +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d)"
  local url="https://api.github.com/search/repositories?q=claude+agent+created:>${since_date}&sort=stars&order=desc&per_page=8"
  if [[ -n "$AUTH_HEADER" ]]; then
    curl -fsSL -H "$AUTH_HEADER" -H "Accept: application/vnd.github+json" "$url" 2>/dev/null
  else
    curl -fsSL -H "Accept: application/vnd.github+json" "$url" 2>/dev/null
  fi
}

parse_repos() {
  python3 - <<'PYEOF'
import sys, json

data = json.load(sys.stdin)
items = data.get("items", [])
seen = set()
for r in items:
    full = r.get("full_name","")
    if full in seen:
        continue
    seen.add(full)
    desc = (r.get("description") or "No description").replace("\n"," ").strip()[:120]
    stars = r.get("stargazers_count", 0)
    lang  = r.get("language") or "—"
    url   = r.get("html_url","")
    pushed = (r.get("pushed_at","") or "")[:10]
    print(f"| [{full}]({url}) | {stars:,} ⭐ | {lang} | {desc} | {pushed} |")
PYEOF
}

fetch_section() {
  local label="$1"
  local query="$2"
  echo "### 🔍 \`${query}\`"
  echo ""
  echo "| Repo | Stars | Lang | Description | Last Push |"
  echo "|------|-------|------|-------------|-----------|"
  local result
  result="$(gh_search "$query")"
  if echo "$result" | python3 -c "import sys,json; json.load(sys.stdin)" &>/dev/null; then
    echo "$result" | parse_repos
  else
    echo "| ⚠️ Rate limited or no results | — | — | Try adding GH_TOKEN | — |"
  fi
  echo ""
}

# ── New Repos (created in last 24h) ──────────────────────────────────────────
fetch_new_repos() {
  echo "## 🆕 New Repos (last 24 h)"
  echo ""
  echo "| Repo | Stars | Lang | Description | Created |"
  echo "|------|-------|------|-------------|---------|"
  local result
  result="$(gh_trending)"
  if echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); [print(f'| [{r[\"full_name\"]}]({r[\"html_url\"]}) | {r[\"stargazers_count\"]:,} ⭐ | {r.get(\"language\") or \"—\"} | {(r.get(\"description\") or \"No description\")[:100]} | {(r.get(\"created_at\") or \"\")[:10]} |') for r in d.get(\"items\",[])]" 2>/dev/null; then
    :
  else
    echo "| ⚠️ No new repos found or rate limited | — | — | — | — |"
  fi
  echo ""
}

# ── GitHub Discussions / Issues mentions ─────────────────────────────────────
fetch_discussions() {
  local since_date
  since_date="$(date -d '1 day ago' +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d)"
  local url="https://api.github.com/search/issues?q=claude+code+agent+subagent+skills+updated:>${since_date}&sort=updated&order=desc&per_page=5"
  echo "## 💬 Hot Discussions & Issues (last 24 h)"
  echo ""
  echo "| Title | Repo | Type | Updated |"
  echo "|-------|------|------|---------|"
  local result
  if [[ -n "$AUTH_HEADER" ]]; then
    result="$(curl -fsSL -H "$AUTH_HEADER" -H "Accept: application/vnd.github+json" "$url" 2>/dev/null)"
  else
    result="$(curl -fsSL -H "Accept: application/vnd.github+json" "$url" 2>/dev/null)"
  fi
  echo "$result" | python3 - <<'PYEOF'
import sys, json
try:
    data = json.load(sys.stdin)
    items = data.get("items", [])
    for i in items:
        title = i.get("title","").replace("|","\\|")[:80]
        url   = i.get("html_url","")
        repo  = i.get("repository_url","").replace("https://api.github.com/repos/","")
        kind  = "PR" if i.get("pull_request") else "Issue"
        updated = (i.get("updated_at","") or "")[:10]
        print(f"| [{title}]({url}) | {repo} | {kind} | {updated} |")
except:
    print("| ⚠️ Rate limited or parse error | — | — | — |")
PYEOF
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  echo "⏳ Building Claude Code / Agent digest for ${DATE}..."

  cat > "$OUTPUT_FILE" <<HEADER
# 🤖 Claude Code · Agent / Subagent / Skills Digest
**Date:** ${DATE}
**Source:** GitHub API · auto-generated by fetch_cc_digest.sh

---

## 📈 Trending This Week — by Topic

HEADER

  for q in "${QUERIES[@]}"; do
    fetch_section "topic" "$q" >> "$OUTPUT_FILE"
  done

  fetch_new_repos >> "$OUTPUT_FILE"
  fetch_discussions >> "$OUTPUT_FILE"

  cat >> "$OUTPUT_FILE" <<FOOTER

---

## 🔗 Quick Links
- [Claude Code Docs](https://docs.anthropic.com/en/docs/claude-code)
- [Anthropic SDK](https://github.com/anthropics/anthropic-sdk-python)
- [claude.ai](https://claude.ai)
- [GitHub Search: claude agent](https://github.com/search?q=claude+agent&sort=stars&type=repositories)

*Generated at $(date '+%Y-%m-%d %H:%M %Z') — add \`GH_TOKEN\` env var to avoid rate limits*
FOOTER

  echo "✅ Digest written to: ${OUTPUT_FILE}"
}

main
