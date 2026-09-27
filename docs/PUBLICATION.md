# Public repository release

Publish only the reviewed `public/preparar-publicacion` branch as the remote
`main` branch. It is a clean, single-commit snapshot; do not push local
development branches or tags. Refresh the snapshot after any later edits.

The project code and original documentation use the MIT License in `LICENSE`.
It does not grant rights to third-party material. The preview photographs whose
only recorded source was Cosmos had no recoverable original source URLs, license
terms or complete attribution. They were removed from the shareable repository;
the review is recorded in `THIRD_PARTY_NOTICES.md`. Do not re-add them unless
redistribution rights and any attribution requirements are documented.

Before publishing:

- Check the public branch tree and its complete Git history for private content.
- Use a hosting-provider privacy email for any future commits to the public
  branch.
- Keep local environment files, credentials, signing keys and application
  stores out of Git. The repository `.gitignore` covers common local files.
- Share a repository link from the post; do not package the entire worktree
  directory, which contains local Git metadata.
