# Dotfiles

Personal dev environment configuration. Managed with git; deployed via plain copies.

## Structure

```
.
├── nvim/            # Daily-driver Neovim config (full-stack web, lazy.nvim)
├── nvim-java/       # Isolated Java/DSA Neovim config (NVIM_APPNAME=nvim-java)
├── setup-scripts/   # Shell utilities (concat, git identity, repo-to-AI, node_modules cleaner)
├── .bashrc          # Stock Ubuntu skeleton (bash not the daily shell)
├── .zshrc           # Daily shell: zinit, mise, starship/zoxide/atuin, aliases
├── .tmux.conf       # Tmux configuration
└── .gitignore
```

## Prerequisites

* `git`
* `rsync` (used by the copy-based sync below)
* `mise` providing `neovim` 0.12.x and `java` 21+ (required to run `eclipse.jdt.ls` in `nvim-java`)

## Setup

```
git clone https://github.com/livipi702/dotfiles.git
cd dotfiles
cp .bashrc ~/.bashrc
cp .zshrc ~/.zshrc
cp .tmux.conf ~/.tmux.conf
rsync -a --delete nvim/ ~/.config/nvim/
rsync -a --delete nvim-java/ ~/.config/nvim-java/
source ~/.zshrc
```

Live files are plain copies, not symlinks. Edit in place, then sync back
before committing. The trailing slash on the source is required, and
`--delete` mirrors removals:

```
rsync -a --delete ~/.config/nvim/ nvim/
rsync -a --delete ~/.config/nvim-java/ nvim-java/
```

Do not use `cp -r ~/.config/nvim nvim` here. `nvim/` already exists, so
`cp -r` copies *into* it and leaves a stray `nvim/nvim/`.

## nvim (daily driver)

Full-stack web config. Minimalist `lazy.nvim` setup: `init.lua` loads
`config/{options,lazy,keymaps,autocmds}`, one concern per file under `lua/plugins/`.
`lazy-lock.json` pins plugin versions. `stylua.toml` (`Spaces/2`) governs Lua formatting.

```
nvim
```

## nvim-java (isolated Java/DSA)

Separate build; shares nothing with `nvim/` (own `share/state/cache`, own `lazy-lock.json`).
LSP via `nvim-jdtls` (`ftplugin/java.lua`, per-project `-data` workspace, debug + JUnit
bundles installed through `mason`). Formatting is `jdtls` via `conform.nvim` fallback.
Single-file DSA run: `<leader>r`. Tests: `<leader>df` (class), `<leader>dn` (nearest).

```
NVIM_APPNAME=nvim-java nvim
alias vij='NVIM_APPNAME=nvim-java nvim'
```

First launch installs plugins (`lazy.nvim`) and tools (`mason`: `jdtls`,
`java-debug-adapter`, `java-test`, `stylua`, `tree-sitter-cli`).

## setup-scripts

| Script            | Purpose                                                     |
| ----------------- | ----------------------------------------------------------- |
| `concat.sh`       | Directory merger (aliased as `concat`)                      |
| `git.sh`          | `gitid` — switch between git identities per repo            |
| `git2ai.py`       | Export a git repo as structured XML context for AI          |
| `clean-modules.sh`| Safely find and remove `node_modules` directories           |

## Shell

`.zshrc` is the daily shell: `zinit` plugins, `mise` activation, `EDITOR`/`VISUAL` set
to `nvim`, `eza`/`bat`/`btop`/`lazygit` aliases, `vij` alias, `starship`/`zoxide`/`atuin`
integrations, and `setup-scripts` aliases (`concat`, `git2ai`, `rm-modules`, `git.sh`
sourcing). `MISE_GITHUB_TOKEN` is redacted here — export it in the local shell only.
`.bashrc` is the stock Ubuntu skeleton. `.tmux.conf` uses a portable login shell
(`$SHELL` with `sh` fallback) and pairs `vim-tmux-navigator` with both nvim configs.
