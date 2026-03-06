# Vibecode Observed Workflow

Use this file when the live UI is ambiguous and you need prior evidence about how Vibecode has behaved in earlier sessions.

## Source Evidence

Derived from:

- `/Users/samihalawa/Downloads/PromptPilot-chat-export (1).md`
- `/Users/samihalawa/Downloads/OULANG-chat-export-10.md`

## What Vibecode Appears To Do

### Workspace Build Loop

The exported chats show an internal agent loop built around:

- `Read`
- `Write`
- `Edit`
- `Glob`
- `Bash`
- `TodoWrite`
- named subagents such as `Explore`

That suggests the workspace is backed by a writable filesystem and an internal git checkout, even when the browser UI does not expose git directly.

### GitHub Behavior Seen In PromptPilot

The PromptPilot export contains a concrete GitHub sync sequence:

1. Create a private repo through the GitHub API.
2. Add a `github` remote to the workspace checkout.
3. Push `main` to the new remote.
4. Configure hooks to keep `origin` and `github` in sync.

Observed repo naming pattern:

- `2026-VIBECODEAPP-promptpilot`

Observed operational pattern:

- Vibecode can execute shell git commands inside its workspace.
- The browser user likely needs to open the project and inspect repo/connection/deploy controls rather than expecting a dedicated "export" button.

### GitHub Behavior Seen In Oulang

The Oulang export shows a second pattern:

1. Add a GitHub remote if missing.
2. Fetch both `origin` and `github`.
3. Confirm GitHub is synced to the expected commit.

This indicates Vibecode workspaces can already have a primary `origin` plus an extra GitHub mirror remote.

## Browser Cues To Check

When interacting with the live workspace, inspect these areas in order:

1. Workspace dashboard project card.
2. Workspace header actions such as `Deploy`.
3. Code or connection icon in the header.
4. Left sidebar refresh or updates area.
5. Deploy modal and environment variable tabs.

The user-provided recording also mentions:

- a `Deploy` button,
- a success toast such as `Deployment succeeded`,
- a code icon exposing host and password fields,
- a project textarea with placeholder similar to `Keep building`.

## Practical Interpretation

- If a repo is already linked, prefer reading and cloning it.
- If the repo is not yet linked but the workspace is functional, create the private GitHub repo with `gh`, then use the browser to connect or push the workspace to it.
- If the workspace only exposes connection details, capture them and continue probing settings or code panels before deciding the repo is inaccessible.
