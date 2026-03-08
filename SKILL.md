---
name: vibecodeapp-manager-skill
description: "Operate VibecodeApp workspaces end to end for both first-time setup and ongoing maintenance: inspect the live workspace, align GitHub + Vibecode git + SSH workspace sync, keep committed .env files as the app config source of truth, and deploy the app using the established Cloud Run + Expo/EAS model."
---

# VibecodeApp Manager Skill

## Overview

Use this skill for VibecodeApp projects under `/Users/samihalawa/git/PROJECTS_VIBECODEAPP`, especially when the goal is not just to inspect a workspace but to make the workspace, Git remotes, local repo, SSH checkout, and deploy targets behave like one coherent system.

This skill must handle two modes cleanly:

- First-time setup for a new Vibecode workspace.
- Ongoing maintenance for a workspace that is already linked, deployed, and partially automated.

Treat the live workspace as evidence, not as the source of truth. The source of truth for code is git, and the source of truth for app runtime config is the committed `.env` files inside the repo.

## Hard Rules

- Work on the real local repo under `/Users/samihalawa/git/PROJECTS_VIBECODEAPP`.
- Do not confuse a Vibecode repo with unrelated repos that happen to have similar naming.
- If a project already has an established GitHub repo, reuse it. Do not create duplicates.
- Keep committed `.env` files as the app config source of truth unless the user explicitly asks for a different model.
- Prefer one real backend target for production traffic even if multiple deploy surfaces exist.
- Do not add restrictive CORS policies. Use the most permissive browser-compatible setup needed for the current architecture.
- If the workspace is already in a synchronized state, preserve it and explain it rather than rebuilding it.

## Oulang-Specific Canonical Model

Use this as the reference pattern when the user asks for "the same setup as Oulang" or a similar deployment model.

### Repo Identity

- This repo family is the Vibecode app repo, not `oulang-web`.
- `oulang-web` belongs to the separate MANUS repo `samihalawa/2026-MANUS-oulang`.
- If names are close, keep them explicitly separate in your notes and deployment steps.

### Source Of Truth

- App config lives in committed env files.
- Frontend:
  - `mobile/.env`
  - `mobile/.env.production`
- Backend:
  - `backend/.env`
  - `backend/.env.production`
- GitHub secrets, Expo tokens, and GCP deploy credentials are deploy credentials, not runtime app config.

### Deploy Topology

- Main web + API production target:
  - one combined Cloud Run service from the monorepo root
  - example: `oulang-independent-frontend-backend`
- Additional web target:
  - Expo Hosting / `*.expo.app`
- Native targets:
  - EAS Update for OTA
  - EAS Build for iOS and Android binaries

### Cloud Run Monorepo Pattern

- Build from the repo root with a root `Dockerfile`.
- Export the Expo web app from `mobile/`.
- Copy the web export into the backend public bundle.
- Serve that exported web app from the backend process.
- Keep the Cloud Run service name unambiguous so it cannot be confused with unrelated projects.

### Git Sync Pattern

There are four states to keep aligned:

1. local repo on macOS
2. GitHub repo
3. Vibecode git remote
4. SSH workspace checkout, usually `/home/user/workspace`

Preferred model:

- `origin` multi-pushes to both GitHub and Vibecode git.
- GitHub Actions also mirrors to Vibecode git and fast-forwards the SSH workspace checkout.
- The SSH workspace can also be configured to multi-push back to GitHub so Vibecode-originated commits do not get stranded.

### SSH Workspace Pattern

- Vibecode workspaces often expose SSH access to the running container.
- Treat SSH as a real checkout that must stay aligned with local, GitHub, and Vibecode git.
- Usual repo path inside the container is `/home/user/workspace`.
- Prefer fast-forward pulls over ad hoc file copying.
- Do not hardcode workspace passwords or per-project secrets into the skill; read them from the live workspace connection panel when needed.

### Backend Selection Pattern

Backend URL selection must follow the actual host:

- Combined hosted frontend+backend web can use same-origin API.
- `*.expo.app` should use configured backend env values, not same-origin guessing.
- `*.dev.vibecode.run` and `*.vibecode.run` should use configured backend env values, not same-origin `/api`, because those hosts are frontend-only and can return HTML for API paths.

## When To Use This Skill

Use it when the user asks to:

- connect a Vibecode workspace to GitHub
- clone or sync a Vibecode project locally
- mirror GitHub and Vibecode git
- keep SSH workspace and local checkout aligned
- set up the Oulang-style Cloud Run + Expo deployment model
- deploy a Vibecode repo using Expo Hosting, EAS Update, EAS Build, and Cloud Run
- inspect why Vibecode web, Expo web, or Cloud Run web is hitting the wrong backend
- normalize existing setup instead of starting from scratch

## Inputs To Gather

Collect these before acting:

- Vibecode workspace URL or exact project name
- expected local destination under `/Users/samihalawa/git/PROJECTS_VIBECODEAPP`
- whether a GitHub repo already exists
- whether the project already has Cloud Run, Expo, and EAS wired up
- whether an SSH workspace exists and where it is checked out
- whether the user wants first-time setup or sync/maintenance only

If missing, derive cautiously from the live workspace and current repo state before creating anything.

## Workflow

### 1. Establish Access And Read State First

- Prefer the user's existing logged-in browser session.
- If only cookies are available, convert them with `scripts/build_storage_state.py`.
- Open the workspace and inspect before changing anything.
- Read current local git remotes, latest commit, workflow files, deploy config, and `.env` files.
- Confirm whether this is a fresh workspace or an already-managed one.

### 2. Identify The Existing System

Inspect and record:

- the GitHub repo URL, if any
- the Vibecode git remote URL, if any
- whether the workspace has an SSH host/password connection panel
- whether Cloud Run, Expo Hosting, and EAS are already configured
- whether a combined app+API deployment already exists

Do not create a new repo or deployment surface if one already exists and is meant to stay canonical.

### 3. First-Time Setup Path

If this is a new project, set it up in this order:

1. Create or confirm the private GitHub repo.
2. Link the Vibecode workspace to that repo if not already linked.
3. Clone or sync locally into `/Users/samihalawa/git/PROJECTS_VIBECODEAPP/<repo-name>`.
4. Add or normalize remotes so GitHub and Vibecode git stay mirrored.
5. Confirm the SSH workspace checkout exists and can fast-forward from git.
6. Create the combined Cloud Run service from the monorepo root.
7. Set up Expo Hosting for web and EAS for OTA/native delivery.
8. Add or normalize the GitHub workflow so `main` drives sync and deploy.

### 4. Ongoing Maintenance Path

If the project already exists, do not rebuild it. Instead:

1. Compare local, GitHub, Vibecode git, and SSH workspace commits.
2. Fast-forward the lagging locations.
3. Verify multi-push config still exists where it should.
4. Verify deploy workflow still matches the intended topology.
5. Verify frontend runtime is pointing at the correct backend for each host type.
6. Redeploy only the surfaces affected by the current change.

### 5. Git Alignment

Preferred checks:

```bash
git remote -v
git rev-parse HEAD
git ls-remote origin main
git ls-remote github main
```

If there is an SSH workspace:

```bash
sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no "$SSH_USER@$SSH_HOST" -p "$SSH_PORT" \
  'cd /home/user/workspace && git rev-parse HEAD && git remote -v'
```

Preferred end state:

- local, GitHub, Vibecode git, and SSH workspace all point to the same commit on `main`
- pushes from the canonical workspaces do not silently update only one remote

### 6. Deploy Model

For the Oulang-style pattern, deploy in this order:

1. Cloud Run combined frontend+backend
2. Expo web
3. EAS update
4. optional EAS native builds when a binary-compatible update is not enough

Typical workflow shape:

- mirror to Vibecode git
- fast-forward SSH workspace
- build and deploy Cloud Run
- export and deploy Expo web
- publish EAS OTA update

Use the existing repo workflow if present instead of inventing a second automation path.

### 7. Backend And CORS Rules

Do not overengineer CORS.

- If frontend and backend are served from the same Cloud Run origin, prefer same-origin API calls.
- If a surface is frontend-only, point it at the configured backend URL from env.
- Avoid restrictive allowlists that break Vibecode dev, Expo Hosting, or other legitimate hosts.
- Browser credential flows still require a valid credentials-compatible CORS response, so "remove restrictions" means permissive and correct, not broken wildcard credentials.

### 8. Verification

Always verify:

- workspace UI state after linking/syncing/deploying
- local repo path and remotes
- latest commit on local, GitHub, Vibecode git, and SSH workspace
- Cloud Run health or API endpoint
- web frontend actually loading data from the intended backend
- browser console free of new runtime or CORS errors

Provide concrete evidence:

- repo URL
- local path
- service URL
- latest commit SHA
- deploy URL or workflow run URL

## Browser Guidance

- Prefer session-preserving browser tools when the user is already logged in.
- Re-scan after every modal or deploy step because Vibecode UI changes frequently.
- Use screenshots or snapshots when repository state, deploy state, or environment prompts are visible.
- Trust the live workspace over old assumptions.

## Failure Handling

- If the workspace exists but repo wiring is unclear, inspect connection/code/settings panels before creating anything new.
- If the project is already partially deployed, normalize it instead of replacing it.
- If the wrong backend is being called, fix runtime host selection first before blaming auth or CORS.
- If GitHub and Vibecode have diverged, determine the newest intended source before pushing.
- If there is no underlying git repo for the installed skill or workspace helper files, report that clearly instead of pretending you pushed changes.

## References

- `references/vibecode-observed-workflow.md`
- `scripts/build_storage_state.py`
- `scripts/ensure_private_github_repo.sh`
- `scripts/clone_or_sync_vibecode_repo.sh`
