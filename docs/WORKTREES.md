# Local worktrees for Codex

Each task gets its own Codex task and Git worktree. The manager assigns a unique MCP port and SwiftData store to each worktree, so parallel copies of FIELD do not share those development resources.

## Required start-of-task reminder

At the beginning of every Codex conversation in this repository, recommend opening the task in a dedicated worktree and give a short task slug. For example:

> Create and open `~/Desktop/FIELD-worktrees/reference-search` in Codex for this task.

If the conversation is already in a managed worktree, say it is ready and activate it. Mark a worktree inactive only after no Codex conversation is using it and its FIELD app is stopped. This instruction applies to Codex conversations working in FIELD; it does not configure other repositories.

## Create and open a task worktree

Once the initial local commit exists on `main`, create a task worktree with:

```sh
cd ~/Desktop/FIELD
python3 scripts/worktree.py create reference-search
```

The manager creates branch `task/reference-search` under `~/Desktop/FIELD-worktrees/reference-search`. Open that folder as the task workspace in Codex. When resuming an existing worktree, run `python3 scripts/worktree.py activate` from inside it (or pass its slug from the main checkout).

## Ports and environment

FIELD currently has one local development service: the optional HTTP MCP listener inside the macOS app. There is no Docker, Node, or separate web server stack in this Swift package.

| Variable | Purpose | Worktree behavior |
| --- | --- | --- |
| `FIELD_MCP_PORT` | Preferred loopback port for the MCP listener | Manager reserves a distinct port from `8765`–`8800` for each worktree. If that port becomes occupied, the app tries the rest of the range. |
| `FIELD_DATA_DIR` | On-disk SwiftData store directory | Manager assigns `~/Library/Application Support/Field LAB/worktrees/<slug>` so each worktree has an isolated database. |
| `FIELD_MCP_TOKEN` | Fallback bearer token for MCP clients that cannot use the Keychain helper | Secret only; never put it in the generated environment file or commit it. |

The manager stores each assignment in a shared local registry and writes `FIELD_MCP_PORT` and `FIELD_DATA_DIR` to `.field-worktree.env`, which is ignored by Git. `scripts/worktree.py start` launches `swift run FIELD` with the registered settings. If launching from Xcode instead, add the two values from that env file to the Run scheme's environment. The default app launch without `FIELD_DATA_DIR` continues using its normal local store.

Useful commands:

```sh
python3 scripts/worktree.py list
python3 scripts/worktree.py start             # from inside a managed worktree
python3 scripts/worktree.py start reference-search  # from any FIELD checkout
```

## Merge and reclaim worktrees

Finish and commit the task in its worktree. Then merge it locally into `main`:

```sh
cd ~/Desktop/FIELD
git -C ~/Desktop/FIELD switch main
git -C ~/Desktop/FIELD merge --no-ff task/reference-search
python3 scripts/worktree.py deactivate reference-search
```

The task's port reservation becomes reclaimable after its MCP listener is stopped, the worktree is clean, and it is marked inactive. When the port pool fills—or whenever you want to remove old checkouts—run:

```sh
cd ~/Desktop/FIELD
python3 scripts/worktree.py prune
```

The cleanup asks before removing each candidate. It skips active worktrees, dirty checkouts, the current shell's worktree, and any worktree whose assigned port is still in use. It removes only the checkout and releases its port reservation; the task branch and isolated database are kept. Remove a branch manually after confirming it has merged, and delete its database directory only when that local data is no longer needed.

`scripts/worktree.py start` uses `swift run FIELD`, so it needs an Xcode toolchain that can build the SwiftData models. If the active Command Line Tools cannot build `SwiftDataMacros`, set the full Xcode toolchain with `xcode-select` or launch from Xcode using the worktree's two environment values.

All operations stay local. Do not add a remote or push unless explicitly requested.
