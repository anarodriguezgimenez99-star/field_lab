# Local development workflow

- Before any task work in every Codex conversation in this repository, recommend opening that task in a dedicated Codex worktree. Include the command `python3 scripts/worktree.py create <task-slug>`, suggested `task/<task-slug>` branch and `~/Desktop/FIELD-worktrees/<task-slug>` path, even for investigation-only tasks. If already in the right worktree, activate it with `python3 scripts/worktree.py activate` and recommend continuing there.
- Do not implement task changes in the `main` checkout. Create or use a task branch and Git worktree based on the latest local `main` using the worktree manager so it receives a unique port and isolated data directory.
- `main` is the local integration branch. Put worktrees beside this checkout in `../FIELD-worktrees/<task-slug>` and name branches `task/<task-slug>`.
- Finish and review the task in its worktree before merging it into `main`. Merge locally with `git merge --no-ff task/<task-slug>` so each completed task stays visible in history.
- Keep all work local. Do not add a remote or push unless the user explicitly asks.
- When a task is completed or paused and no Codex conversation is using its worktree, stop the FIELD app and mark it inactive with `python3 scripts/worktree.py deactivate <task-slug>`. After a successful merge, remove its worktree; keep the branch unless the user asks to delete it.

See [docs/WORKTREES.md](docs/WORKTREES.md) for the user workflow and commands.
