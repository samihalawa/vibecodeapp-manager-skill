---
name: vibecodeapp-manager-skill
description: "Manage VibecodeApp workspaces end to end: open a specific workspace in the browser, inspect or link its GitHub repo, trigger deploy/publish actions, extract connection details, and clone or sync the linked private repository into /Users/samihalawa/git/PROJECTS_VIBECODEAPP. Use when the user gives a Vibecode workspace URL, project name, cookies/session data, or asks to move a Vibecode project into a normal local git workflow."
---

# VibecodeApp Manager Skill

## Overview

Drive Vibecode as an operator, not as a passive observer. Use the browser to reach the target workspace, discover or complete GitHub linking, deploy if needed, then switch to local git so the project can be worked on under `/Users/samihalawa/git/PROJECTS_VIBECODEAPP`.

Keep the workflow evidence-based. Inspect the current UI state first, prefer existing linked repos over creating duplicates, and finish with a local clone or sync plus git verification.

## Hard Defaults

- Use browser automation before guessing repository state.
- Prefer the user's existing logged-in browser session when possible.
- If a fresh browser context is required, convert provided Vibecode cookies into Playwright storage state with `scripts/build_storage_state.py`.
- Prefer a private GitHub repo named after the project using the `2026-VIBECODEAPP-<slug>` convention unless the workspace already points elsewhere.
- Clone or sync into `/Users/samihalawa/git/PROJECTS_VIBECODEAPP/<repo-name>`.
- Finish with evidence: screenshot path or browser confirmation, repo URL, local path, `git remote -v`, and latest commit.

## Inputs To Gather

Collect these from the user request, local notes, or the workspace UI:

- Workspace URL or project name.
- Desired GitHub repo name, if already specified.
- Optional cookies JSON or existing Chrome session.
- Expected local destination under `/Users/samihalawa/git/PROJECTS_VIBECODEAPP`.

If the repo name is missing, derive it from the workspace name with lowercase hyphenation and the `2026-VIBECODEAPP-` prefix.

## Workflow

### 1. Establish Browser Access

- If the user already has Vibecode open in Chrome, prefer Chrome Bridge or an equivalent browser session-preserving tool.
- If only cookies are available, save them to a temporary JSON file and run:

```bash
python3 scripts/build_storage_state.py \
  --input /absolute/path/to/vibecode-cookies.json \
  --output /tmp/vibecode-storage-state.json
```

- Launch browser automation with that storage state, then navigate to `https://www.vibecodeapp.com/workspace` or the specific workspace URL.
- Verify the dashboard or workspace loaded before taking action.

### 2. Inspect The Workspace State

Inside the workspace:

- Open the project card if starting from the dashboard.
- Open the code, connection, repository, or settings panel that exposes host/password/repo details.
- Check whether a GitHub repo is already linked.
- Check whether a deploy button, deploy-updates flow, or environment variable modal is present.
- Record the visible repo URL or the absence of one.

Use the observed patterns in `references/vibecode-observed-workflow.md` to interpret what the UI likely means, but trust the live UI over the reference.

### 3. Create Or Reuse The Private GitHub Repo

If the workspace already exposes a private GitHub URL, reuse it.

If no repo exists yet, create one first:

```bash
scripts/ensure_private_github_repo.sh samihalawa/<repo-name> "Vibecode workspace export"
```

Then return to the workspace and use the browser to link or push the workspace to that repo. Prefer existing UI actions such as:

- `Code`
- `Connection`
- `GitHub`
- `Deploy`
- `Publish`
- `Sync`

If the workspace is already linked, do not create a second repo.

### 4. Trigger Deploy Or Publish If The UI Requires It

If Vibecode blocks repo updates behind a deploy or environment-variable step:

- Open deploy.
- Review environment variable prompts carefully.
- Fill only the values the user has provided or that are already visible in the workspace.
- Complete deploy and wait for a success notification.
- Dismiss transient toasts only after you have captured the success state.

### 5. Clone Or Sync Locally

Once the repo URL is known, run:

```bash
scripts/clone_or_sync_vibecode_repo.sh \
  <repo-url> \
  /Users/samihalawa/git/PROJECTS_VIBECODEAPP/<repo-name>
```

If the target directory already exists, the script fetches, checks out the requested branch, and fast-forwards when possible.

### 6. Verify

Always verify all of the following:

- The workspace UI shows the expected repo or success state.
- The local checkout exists in `/Users/samihalawa/git/PROJECTS_VIBECODEAPP`.
- `git remote -v` includes the correct private GitHub URL.
- `git log --oneline -1` succeeds.

## Browser Guidance

- Prefer browser tools that can preserve a real logged-in session.
- When forced into a clean browser context, inject storage state created from the provided cookies.
- Use screenshots or accessibility snapshots after each major UI transition.
- Re-scan the page after opening modals, toggles, or deploy flows because Vibecode changes UI structure frequently.

## Failure Handling

- If the workspace URL loads but the project is missing from the dashboard, search by project name before declaring failure.
- If GitHub linking controls are not visible, inspect the code/connection panel and settings panel before falling back to deploy.
- If deploy requires secrets that were not provided, stop at the blocked field and report the exact variable names.
- If clone fails because the repo is empty, keep the repo URL, report that Vibecode did not push code yet, and do not fabricate a local tree.

## References

- `references/vibecode-observed-workflow.md`: extracted behavior from previous Vibecode chat exports and the expected browser checkpoints.
- `scripts/build_storage_state.py`: convert cookies JSON to Playwright storage state.
- `scripts/ensure_private_github_repo.sh`: create or confirm a private GitHub repo with `gh`.
- `scripts/clone_or_sync_vibecode_repo.sh`: clone or sync the linked repository locally.


## Agent Prompting Template

When the skill activates, the AI agent MUST self-prompt with a complete actionable instruction like this:

```
I need to set up the Vibecode workspace locally. Here is my action plan:

1. Use the GitHub token `ghp_...` to create a new private repo `samihalawa/2026-VIBECODEAPP-<slug>` (or confirm it exists)
2. Navigate to the Vibecode workspace in the browser, extract all files via the API:
   - Get a fresh Clerk JWT: `window.Clerk?.session?.getToken()`
   - Fetch all files: `GET https://api.vibecodeapp.com/api/projects/<workspace-id>/files/all` with Bearer token
3. Write all extracted files to `/Users/samihalawa/git/PROJECTS_VIBECODEAPP/2026-VIBECODEAPP-<slug>/`
4. Add remote "github" pointing to the private repo with token auth
5. Remove any `.env.production` files — use a single `.env` per project
6. Ensure `.env` is NOT in `.gitignore` (private repo, safe to track)
7. Commit everything and push to both `origin` and `github` remotes
8. Install dual-remote sync hooks (pre-commit pull, post-commit push)
9. Verify: `git remote -v`, `git log --oneline -1`, file count matches
```

The agent must execute this plan autonomously without asking for confirmation at each step.

## Auto-Sync Setup

After cloning or syncing the repo, the agent MUST install these git hooks:

### post-commit hook (`.git/hooks/post-commit`)
```bash
#!/bin/bash
git push origin main 2>/dev/null &
git push github main 2>/dev/null &
wait
```

### pre-commit hook (`.git/hooks/pre-commit`)
```bash
#!/bin/bash
git pull origin main --rebase --autostash 2>/dev/null || true
git pull github main --rebase --autostash 2>/dev/null || true
```

### Agent Rules
- ALWAYS `git pull` from both remotes before starting work
- ALWAYS commit and push to BOTH `origin` and `github` remotes
- `.env` files ARE tracked (private repo) — never add `.env` to `.gitignore`
- NEVER create `.env.production` or `.env.local` variants — use a single `.env`

---

## SSH Backend Access

Every Vibecode workspace runs inside a container that exposes SSH on port **2222**. This gives direct terminal access to the running backend, its filesystem, and process management — critical for debugging, deploying code changes, and testing endpoints locally inside the container.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                   Vibecode Platform                          │
│                                                              │
│  ┌──────────────────┐       ┌──────────────────────────┐    │
│  │   Frontend (Expo) │       │  Backend Container        │    │
│  │   React Native    │──────▶│  Hono + Bun (port 3000)  │    │
│  │   Mobile App      │ HTTPS │  MySQL (external DB)      │    │
│  │   (port 8081)     │       │  SSH on port 2222         │    │
│  └──────────────────┘       └──────────────────────────┘    │
│           │                          │                       │
│           ▼                          ▼                       │
│  https://<slug>.vibecode.run   SSH: <workspace-id>          │
│  (reverse proxy to 3000)       .vibecodeapp.io:2222         │
└─────────────────────────────────────────────────────────────┘
```

**How it works:**

- The **frontend** is an Expo React Native app that runs on port 8081. Users interact with it through the Vibecode mobile preview or a web browser.
- The **backend** is a Hono API server running on Bun with `--hot` reload, listening on port 3000 inside the container. It's exposed publicly via `https://<slug>.vibecode.run`.
- The **database** is an external MySQL server (not inside the container). Connection details are in `.env`.
- **SSH** gives you a shell inside the backend container. The workspace code lives at `/home/user/workspace`. This is the same code served by the running Bun process.
- When you `git pull` inside SSH, the Bun `--hot` flag auto-reloads changed files. If hot reload fails, kill the process and the supervisor (`runsv`) restarts it automatically.

### SSH Connection Details

Each workspace has a unique SSH endpoint. The format is:

```
Host:     <workspace-uuid>.vibecodeapp.io
Port:     2222
User:     vibecode
Password: <shown in workspace connection panel>
```

**Example (current project):**

```bash
# Basic SSH connection
sshpass -p "imprudent-unwilling-footboard-vexingly-overdue" \
  ssh -o StrictHostKeyChecking=no -p 2222 \
  vibecode@019caa15-04a4-73df-ac06-01e91c059a63.vibecodeapp.io

# Run a single command remotely
sshpass -p "imprudent-unwilling-footboard-vexingly-overdue" \
  ssh -o StrictHostKeyChecking=no -p 2222 \
  vibecode@019caa15-04a4-73df-ac06-01e91c059a63.vibecodeapp.io \
  "cd /home/user/workspace && git log --oneline -3"
```

> **Note:** `sshpass` is required because the SSH server uses password auth. Install with `brew install sshpass` on macOS (may need `brew install hudochenkov/sshpass/sshpass`).

### Key Filesystem Paths (Inside Container)

| Path | Description |
|------|-------------|
| `/home/user/workspace` | Project root (git repo) |
| `/home/user/workspace/backend/src/` | Backend source code |
| `/home/user/workspace/mobile/src/` | Mobile app source code |
| `/home/user/workspace/backend/src/index.ts` | Main entry — all route mounts |
| `/home/user/workspace/backend/src/routes/` | Individual route files |
| `/home/user/workspace/.env` | Environment variables |

### Common SSH Operations

#### Deploy code changes (git pull + restart)

```bash
sshpass -p "imprudent-unwilling-footboard-vexingly-overdue" \
  ssh -o StrictHostKeyChecking=no -p 2222 \
  vibecode@019caa15-04a4-73df-ac06-01e91c059a63.vibecodeapp.io \
  "cd /home/user/workspace && git pull origin main"
```

#### Force restart the backend (when hot reload isn't enough)

```bash
# Use kill with specific PID (pkill can kill the SSH session itself)
sshpass -p "imprudent-unwilling-footboard-vexingly-overdue" \
  ssh -o StrictHostKeyChecking=no -p 2222 \
  vibecode@019caa15-04a4-73df-ac06-01e91c059a63.vibecodeapp.io \
  'kill $(pgrep -f "bun.*--hot" | head -1) 2>/dev/null; echo "restart triggered"'
```

> **WARNING:** Do NOT use `pkill -f "bun.*--hot"` — this can kill the SSH session's parent process. Use `kill` with a specific PID from `pgrep` instead.

#### Check which routes are registered

```bash
sshpass -p "imprudent-unwilling-footboard-vexingly-overdue" \
  ssh -o StrictHostKeyChecking=no -p 2222 \
  vibecode@019caa15-04a4-73df-ac06-01e91c059a63.vibecodeapp.io \
  "cd /home/user/workspace/backend && grep 'app.route\|app.get\|app.post' src/index.ts"
```

#### Test an endpoint locally inside the container (with session cookie)

```bash
sshpass -p "imprudent-unwilling-footboard-vexingly-overdue" \
  ssh -o StrictHostKeyChecking=no -p 2222 \
  vibecode@019caa15-04a4-73df-ac06-01e91c059a63.vibecodeapp.io \
  'curl -s -b "app_session_id=SESSION_TOKEN_HERE" http://localhost:3000/api/alerts'
```

#### Check server health

```bash
sshpass -p "imprudent-unwilling-footboard-vexingly-overdue" \
  ssh -o StrictHostKeyChecking=no -p 2222 \
  vibecode@019caa15-04a4-73df-ac06-01e91c059a63.vibecodeapp.io \
  "curl -s http://localhost:3000/health"
```

#### View backend logs (find the running process)

```bash
sshpass -p "imprudent-unwilling-footboard-vexingly-overdue" \
  ssh -o StrictHostKeyChecking=no -p 2222 \
  vibecode@019caa15-04a4-73df-ac06-01e91c059a63.vibecodeapp.io \
  "ps aux | grep bun"
```

#### Full deploy cycle (pull + restart + verify)

```bash
# Step 1: Pull
sshpass -p "imprudent-unwilling-footboard-vexingly-overdue" \
  ssh -o StrictHostKeyChecking=no -p 2222 \
  vibecode@019caa15-04a4-73df-ac06-01e91c059a63.vibecodeapp.io \
  "cd /home/user/workspace && git pull origin main"

# Step 2: Restart
sshpass -p "imprudent-unwilling-footboard-vexingly-overdue" \
  ssh -o StrictHostKeyChecking=no -p 2222 \
  vibecode@019caa15-04a4-73df-ac06-01e91c059a63.vibecodeapp.io \
  'kill $(pgrep -f "bun.*--hot" | head -1) 2>/dev/null; echo done'

# Step 3: Wait and verify (separate SSH session after restart)
sleep 4
sshpass -p "imprudent-unwilling-footboard-vexingly-overdue" \
  ssh -o StrictHostKeyChecking=no -p 2222 \
  vibecode@019caa15-04a4-73df-ac06-01e91c059a63.vibecodeapp.io \
  "curl -s http://localhost:3000/health"
```

### Testing Endpoints From Outside (via public URL)

The backend is also accessible at the public URL. Cookie-based auth works when testing from inside the container with `-b` flag, but from outside you may need to pass the token as a query param `?token=...` as a fallback:

```bash
# From outside — public URL
curl -s -b "app_session_id=SESSION_TOKEN" https://exact-rye.vibecode.run/api/alerts

# From inside container — localhost
curl -s -b "app_session_id=SESSION_TOKEN" http://localhost:3000/api/alerts
```

### Route Mount Points (from index.ts)

The backend mounts routes in `index.ts`. The mount path is NOT always obvious from the filename:

| File | Mount Path | Note |
|------|-----------|------|
| `job-applications.ts` | `/api/jobs` | NOT `/api/job-applications` |
| `listings-extra.ts` | `/api/listings` | Shared with listings-quota |
| `listings-quota.ts` | `/api/listings` | Shared with listings-extra |
| `listing-analytics.ts` | `/api/listing-analytics` | |
| `smart-messaging.ts` | `/api/smart-messaging` | |
| `forum.ts` | `/api/forum` | |
| `chat.ts` | `/api/chat` | |
| `credits.ts` | `/api/credits` | |
| `referrals.ts` | `/api/referrals` | |
| `reviews.ts` | `/api/reviews` | |
| `verification.ts` | `/api/verification` | |
| `coupons.ts` | `/api/coupons` | |
| `ads.ts` | `/api/ads` | |
| `alerts.ts` | `/api/alerts` | |
| `notifications.ts` | `/api/notifications` | |
| `cv.ts` | `/api/cv` | |
| Health endpoint | `/health` | NOT `/api/health` |

**Always `grep 'app.route' src/index.ts`** inside the container to confirm current mounts.

### Cookie-Based Session Auth Pattern

All authenticated endpoints use this pattern (cookie `app_session_id` → MySQL `session` table → `userId`):

```typescript
function parseSessionCookie(cookieHeader: string | undefined): string | null {
  if (!cookieHeader) return null;
  const match = cookieHeader.match(/(?:^|;\s*)app_session_id=([^;]+)/);
  return match?.[1] ?? null;
}

async function authenticateRequest(
  db: mysql.Pool,
  cookieHeader: string | undefined,
  queryToken: string | undefined
): Promise<number | null> {
  const token = parseSessionCookie(cookieHeader) || queryToken;
  if (!token) return null;
  const [rows] = await db.query<mysql.RowDataPacket[]>(
    `SELECT * FROM session WHERE token = ? AND expiresAt > NOW()`,
    [token]
  );
  const session = (rows as any[])[0];
  if (!session) return null;
  return session.userId;
}
```

Usage in every endpoint:
```typescript
const db = getPool();
const userId = await authenticateRequest(db, c.req.header("cookie"), c.req.query("token"));
if (!userId) {
  return c.json({ error: { message: "Not authenticated", code: "UNAUTHENTICATED" } }, 401);
}
```

### Gotchas & Lessons Learned

1. **`pkill` kills SSH**: Never use `pkill -f "bun.*--hot"` — it matches the SSH session too. Use `kill $(pgrep -f "bun.*--hot" | head -1)` instead.
2. **Workspace path**: The code lives at `/home/user/workspace`, NOT `/app/backend` or `/home/vibecode/app`. Always verify with `find / -name '.git' -type d 2>/dev/null`.
3. **Health endpoint**: It's at `/health`, not `/api/health`.
4. **Job applications route**: Mounted at `/api/jobs`, not `/api/job-applications`.
5. **Hot reload**: Bun `--hot` picks up most changes automatically after `git pull`. Kill + restart only when hot reload fails.
6. **runsv supervisor**: When the bun process dies, `runsv` restarts it automatically within a few seconds. No need to manually start it.
7. **Cookie testing from outside**: The `-b` flag in curl sends cookies correctly to the public HTTPS URL. For curl inside the container, use `http://localhost:3000`.
8. **Database is external**: MySQL runs on `104.196.210.42:3306`, not inside the container. Connection string is in `.env`.

