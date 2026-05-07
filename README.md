# 🤖 Daily Claude Code · Agent / Skills Digest

Automatically tracks **trending and new GitHub repos, issues, and discussions** related to:
- Claude Code CLI
- Agent / Subagent patterns
- Agent teams & orchestration
- Skills / hooks / MCP

Runs via **GitHub Actions at 2 AM UTC daily** → commits digest `.md` to this repo → emails to `amitsahuwin@gmail.com`.

---

## 📁 Files

| File | Purpose |
|------|---------|
| `fetch_cc_digest.sh` | Local bash script — run on demand to generate a digest |
| `.github/workflows/daily_digest.yml` | GitHub Action — automated daily run + email |
| `digest_YYYY-MM-DD.md` | Generated digest files (committed by the Action) |

---

## 🚀 One-Time Setup

### Step 1 — Gmail App Password
1. Go to [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)
2. Type `GitHub Actions` in the App name field → **Create**
3. Copy the 16-character password shown

> ⚠️ 2-Step Verification must be ON for App Passwords to appear.

### Step 2 — GitHub PAT
1. Go to [github.com/settings/tokens/new](https://github.com/settings/tokens/new)
2. Note: `DailyCCSkills`, Expiration: No expiration, Scope: `public_repo`
3. **Generate token** → copy it

### Step 3 — Add 3 Repo Secrets
Go to: **Settings → Secrets → Actions → New repository secret**

| Secret Name | Value |
|-------------|-------|
| `GMAIL_USER` | `amitsahuwin@gmail.com` |
| `GMAIL_APP_PASSWORD` | 16-char App Password from Step 1 |
| `GH_TOKEN` | PAT from Step 2 |

### Step 4 — Test
Go to **Actions → Daily Claude Code Agent Digest → Run workflow**

---

## 💻 Local Usage

```bash
# Without auth (60 req/hr GitHub rate limit)
./fetch_cc_digest.sh

# With your GitHub PAT (5000 req/hr)
GH_TOKEN=ghp_xxxx ./fetch_cc_digest.sh
```

---

## 🕑 Schedule
Runs at **02:00 UTC** = **07:30 AM IST** every day.
