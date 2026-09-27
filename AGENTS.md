# Local development workflow

- Before task work in every Codex conversation for this repository, recommend opening or continuing in a dedicated Codex-managed worktree based on the latest local `main`. Suggest a `task/<task-slug>` branch, including for investigation-only work. Do not recommend creating Codex task worktrees with raw `git worktree add` or with the FIELD resource manager.
- Do not implement task changes in the `main` checkout. Codex-managed worktrees start detached by default; create the task branch with Codex's **Create branch here** action in the task header, named `task/<task-slug>`, before editing. Then run `python3 scripts/worktree.py register`. If already in a registered worktree, run `python3 scripts/worktree.py activate` and recommend continuing there.
- `main` is the local integration branch. Codex owns worktree creation, task association, and worktree cleanup; `scripts/worktree.py` only assigns local development resources and reports capacity. Never use it or `git worktree remove` to delete a Codex-managed worktree.
- Finish and review the task in its worktree before merging it into `main`. Merge locally with `git merge --no-ff task/<task-slug>` so each completed task stays visible in history.
- Keep all work local. Do not add a remote or push unless the user explicitly asks.
- When a task is completed or paused, stop the FIELD app and mark it inactive with `python3 scripts/worktree.py deactivate <task-slug>`. Merge completed branches into local `main` first. Reclaim a Codex-managed checkout by archiving its completed task in Codex; Codex handles cleanup and preserves a snapshot for restoration. Do not remove its directory through Git or the resource manager. Keep the task branch unless the user asks to delete it.

See [docs/WORKTREES.md](docs/WORKTREES.md) for the user workflow and commands.
