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

