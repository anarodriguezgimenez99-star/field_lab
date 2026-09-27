# Codex-managed worktrees

Use Codex's default managed worktree for each task. Codex creates and tracks the checkout for its chat; `scripts/worktree.py` only assigns local FIELD development resources. It never creates or deletes a Codex worktree.

## Start a task

At the start of every Codex conversation in this repository, recommend opening the task in a Codex-managed worktree based on local `main`. If the conversation is already in its task worktree, identify it and recommend continuing there.

In Codex, select **Worktree** when starting a task and choose local `main` as the base. Codex normally starts the checkout on a detached `HEAD`. Before editing, use **Create branch here** in the task header and name the branch `task/<task-slug>` (for example, `task/reference-search`). Then, from that worktree, reserve its FIELD resources:

```sh
python3 scripts/worktree.py register
```

The manager records an ignored `.field-worktree.json` and writes an ignored `.field-worktree.env` in that checkout. It does not modify shared `.git` state or create a Git branch. Register again after returning to a worktree if its local metadata is missing. Each Codex worktree has its own copy of these ignored files.

## Local ports and data

FIELD currently has one optional local service: the HTTP MCP listener inside the macOS app. The Swift package does not use a Docker, Node, or separate web-server stack.

| Variable | Purpose | Worktree behavior |
| --- | --- | --- |
| `FIELD_MCP_PORT` | Preferred loopback port for the MCP listener | The manager assigns a distinct port from `8765`–`8800` to each registered worktree. The app can try the rest of this range if its preferred port is occupied. |
| `FIELD_DATA_DIR` | On-disk SwiftData store directory | The manager uses `~/Library/Application Support/Field LAB/worktrees/<task-slug>` to isolate each task's database. |
| `FIELD_MCP_TOKEN` | Fallback bearer token for MCP clients that cannot use the Keychain helper | Treat as a secret. Never put it in the generated env file or commit it. |

Useful commands:

```sh
python3 scripts/worktree.py list
python3 scripts/worktree.py activate       # resume this registered worktree
python3 scripts/worktree.py start          # launch FIELD with its assigned port and store
python3 scripts/worktree.py start reference-search  # target a registered task from another checkout
```

`start` runs `swift run FIELD`. To launch from Xcode, add `FIELD_MCP_PORT` and `FIELD_DATA_DIR` from `.field-worktree.env` to the Run scheme. If the app is already running, stop and restart it after registering so it reads the assigned values.

`list` shows registered and unregistered Codex worktrees, their resource assignments, activity markers, whether each assigned port is bound, and how many unassigned ports remain. Use `deactivate <task-slug>` after stopping the app and when its task is complete or paused. An inactive marker is informational: it does not release that worktree's port while Codex still keeps the checkout.

## Merge and reclaim capacity

Complete and review the task in its Codex worktree, commit its `task/<task-slug>` branch, then merge that branch into the local integration checkout:

```sh
cd ~/Desktop/FIELD
git switch main
git merge --squash task/reference-search
git commit -m "Describe the completed change"
```

The squash merge creates one integration commit on `main`; the task branch commits remain local. The task branch can be integrated while its Codex worktree still has it checked out. Keep the branch unless you explicitly want to delete it. Mark the worktree inactive from inside that task checkout after stopping FIELD:

```sh
python3 scripts/worktree.py deactivate
```

When the port pool is exhausted, `list` identifies inactive tasks and remaining capacity. Stop their FIELD processes, merge any completed work, then archive the corresponding completed task in Codex. Codex owns the managed worktree's cleanup and saves a snapshot before deleting it; the manager never runs `git worktree remove` or deletes Codex-managed directories. Archiving a task reclaims its checkout, and its ignored port metadata disappears with it. Codex keeps up to 15 recent managed worktrees by default; the limit and automatic cleanup behavior are configurable in Codex Settings > Worktrees. Permanent worktrees are not cleaned up by archiving their chats, so use the Codex UI to remove those if one was deliberately created.

Keep the repository and all merges local. Do not add a remote or push unless explicitly requested.

`swift run FIELD` needs an Xcode toolchain that can build the SwiftData models. If the active Command Line Tools cannot build `SwiftDataMacros`, select the full Xcode toolchain or launch from Xcode using the worktree environment values.
