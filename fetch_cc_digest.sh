#!/usr/bin/env bash
# =============================================================================
# fetch_cc_digest.sh
# Daily Claude Code / Agent / Subagent / Skills GitHub Digest
# Usage:  ./fetch_cc_digest.sh [GITHUB_TOKEN]
#         or set GH_TOKEN env var
# Output: digest_YYYY-MM-DD.md  (in the same directory as this script)
# =============================================================================

set -uo pipefail   # NOTE: no -e so a broken pipe never kills the script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATE="$(date +%Y-%m-%d)"
OUTPUT_FILE="${SCRIPT_DIR}/digest_${DATE}.md"
TOKEN="${GH_TOKEN:-${1:-}}"
AUTH_HEADER=""
[[ -n "$TOKEN" ]] && AUTH_HEADER="Authorization: Bearer ${TOKEN}"

QUERIES=(
  "claude-code agent"
  "claude subagent agent-sdk"
  "anthropic agent skill"
  "claude code hooks mcp"
  "claude agent team orchestration"
  "anthropic claude-code cli"
)

# ── portable date math (macOS + Linux) ───────────────────────────────────────
days_ago() {
  python3 -c "
import datetime
print((datetime.date.today() - datetime.timedelta(days=$1)).isoformat())
"
}

# ── safe curl: writes JSON to a temp file, validates, returns path ────────────
# Never pipes large JSON through shell variables or argv — avoids broken pipe.
safe_curl() {
  local url="$1"
  local tmp
  tmp="$(mktemp /tmp/gh_resp.XXXXXX)"

  local http_code=0
  if [[ -n "$AUTH_HEADER" ]]; then
    http_code=$(curl -fsSL --max-time 20 \
      -H "$AUTH_HEADER" \
      -H "Accept: application/vnd.github+json" \
      -w "%{http_code}" -o "$tmp" \
      "$url" 2>/dev/null) || true
  else
    http_code=$(curl -fsSL --max-time 20 \
      -H "Accept: application/vnd.github+json" \
      -w "%{http_code}" -o "$tmp" \
      "$url" 2>/dev/null) || true
  fi

  # Validate the file contains parseable JSON with an "items" key
  if python3 -c "
import sys, json
try:
    d = json.load(open(sys.argv[1]))
    assert 'items' in d
except:
    sys.exit(1)
" "$tmp" 2>/dev/null; then
    echo "$tmp"
  else
    # Return a valid fallback file
    echo '{"items":[]}' > "$tmp"
    echo "$tmp"
  fi
}

# ── render repo table rows from a JSON file ───────────────────────────────────
parse_repos_file() {
  local file="$1"
  local date_col="${2:-pushed_at}"   # pushed_at or created_at
  python3 - "$file" "$date_col" <<'PYEOF'
import sys, json
file, date_col = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(file))
except Exception:
    data = {}
items = data.get("items", [])
seen = set()
rows = []
for r in items:
    full = r.get("full_name", "")
    if not full or full in seen:
        continue
    seen.add(full)
    desc  = (r.get("description") or "No description").replace("\n", " ").strip()[:120]
    stars = r.get("stargazers_count", 0)
    lang  = r.get("language") or "—"
    url   = r.get("html_url", "")
    date  = (r.get(date_col, "") or "")[:10]
    rows.append(f"| [{full}]({url}) | {stars:,} ⭐ | {lang} | {desc} | {date} |")
if rows:
    print("\n".join(rows))
else:
    msg = data.get("message", "")
    hint = f" ({msg})" if msg else " — set GH_TOKEN to raise API limits"
    print(f"| ⚠️ No results{hint} | — | — | — | — |")
PYEOF
  rm -f "$file"
}

# ── weekly trending section ───────────────────────────────────────────────────
fetch_section() {
  local query="$1"
  local since
  since="$(days_ago 7)"
  local encoded_q
  encoded_q="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$query")"
  local url="https://api.github.com/search/repositories?q=${encoded_q}+pushed:>${since}&sort=stars&order=desc&per_page=5"

  echo "### 🔍 \`${query}\`"
  echo ""
  echo "| Repo | Stars | Lang | Description | Last Push |"
  echo "|------|-------|------|-------------|-----------|"
  local tmp
  tmp="$(safe_curl "$url")"
  parse_repos_file "$tmp" "pushed_at"
  echo ""
}

# ── new repos created in last 24h ─────────────────────────────────────────────
fetch_new_repos() {
  local since
  since="$(days_ago 1)"
  local url="https://api.github.com/search/repositories?q=claude+agent+created:>${since}&sort=stars&order=desc&per_page=8"

  echo "## 🆕 New Repos (last 24 h)"
  echo ""
  echo "| Repo | Stars | Lang | Description | Created |"
  echo "|------|-------|------|-------------|---------|"
  local tmp
  tmp="$(safe_curl "$url")"
  parse_repos_file "$tmp" "created_at"
  echo ""
}

# ── hot issues & discussions (last 24h) ───────────────────────────────────────
fetch_discussions() {
  local since
  since="$(days_ago 1)"
  local url="https://api.github.com/search/issues?q=claude+code+agent+subagent+skills+updated:>${since}&sort=updated&order=desc&per_page=5"

  echo "## 💬 Hot Discussions & Issues (last 24 h)"
  echo ""
  echo "| Title | Repo | Type | Updated |"
  echo "|-------|------|------|---------|"
  local tmp
  tmp="$(safe_curl "$url")"
  python3 - "$tmp" <<'PYEOF'
import sys, json
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    data = {}
items = data.get("items", [])
if not items:
    print("| — | — | — | No results |")
else:
    for i in items:
        title   = (i.get("title", "") or "").replace("|", "\\|")[:80]
        url     = i.get("html_url", "")
        repo    = (i.get("repository_url", "") or "").replace("https://api.github.com/repos/", "")
        kind    = "PR" if i.get("pull_request") else "Issue"
        updated = (i.get("updated_at", "") or "")[:10]
        print(f"| [{title}]({url}) | {repo} | {kind} | {updated} |")
PYEOF
  rm -f "$tmp"
  echo ""
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
  echo "⏳ Building Claude Code / Agent digest for ${DATE}..."

  {
    printf "# 🤖 Claude Code · Agent / Subagent / Skills Digest\n"
    printf "**Date:** %s\n" "$DATE"
    printf "**Source:** GitHub API · auto-generated by fetch_cc_digest.sh\n\n"
    printf -- "---\n\n"
    printf "## 📈 Trending This Week — by Topic\n\n"

    for q in "${QUERIES[@]}"; do
      fetch_section "$q"
    done

    fetch_new_repos
    fetch_discussions

    printf -- "---\n\n"
    printf "## 🔗 Quick Links\n"
    printf -- "- [Claude Code Docs](https://docs.anthropic.com/en/docs/claude-code)\n"
    printf -- "- [Anthropic SDK](https://github.com/anthropics/anthropic-sdk-python)\n"
    printf -- "- [claude.ai](https://claude.ai)\n"
    printf -- "- [GitHub Search: claude agent](https://github.com/search?q=claude+agent&sort=stars&type=repositories)\n\n"
    printf "*Generated at %s — set GH_TOKEN env var to avoid rate limits*\n" "$(date '+%Y-%m-%d %H:%M %Z')"
  } > "$OUTPUT_FILE"

  echo "✅ Digest written to: ${OUTPUT_FILE}"
}

main
