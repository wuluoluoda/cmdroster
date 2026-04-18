# Publishing CmdRoster to GitHub (one-time)

Public repo name: **`cmdroster`** (no personal name in the URL). The zsh command stays **`luo`**.

Your local repo is ready under this folder (its own `.git` on `main`).

1. On GitHub: **New repository** → name **`cmdroster`** → Public → **do not** add README / .gitignore / license (already in the tree).

2. In a terminal:

```bash
cd /path/to/cmdroster   # this directory (contains install.sh)
git remote add origin https://github.com/wuluoluoda/cmdroster.git
git branch -M main
git push -u origin main
```

3. Set the repository **About** description (optional):

> CmdRoster — command-line and script management for zsh on macOS

4. Verify the one-liner (after `main` exists on GitHub):

```bash
curl -fsSL https://raw.githubusercontent.com/wuluoluoda/cmdroster/main/install.sh | bash
```

If your GitHub username is not `wuluoluoda`, replace it in `install.sh` (`GITHUB_RAW`), `README.md`, and `LICENSE` (copyright line), then commit and push again.

**If you already pushed to `wuluoluoda/luo`:** create `cmdroster` as above, change `git remote` to the new URL, and push; you can archive or delete the old `luo` repo on GitHub when ready.
