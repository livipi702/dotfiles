# Dotfiles

This repository contains my personal development environment configuration. It is structured to keep editor setup, shell configuration, and utility scripts organized and reusable across systems.

---

## Structure

```
.
├── nvim/            # Neovim configuration (lazy.nvim based)
├── setup-scripts/   # Scripts for installing development tools
├── 05-scripts/      # General-purpose utility scripts and templates
├── .bashrc          # Shell configuration
├── .tmux.conf       # Tmux configuration
├── .gitignore
```

---

## Overview

The goal of this repository is to provide a reproducible and portable setup for development. It includes:

* Neovim configuration with modular plugin setup
* Shell configuration with aliases, environment variables, and script integration
* Tmux configuration for terminal workflow
* Setup scripts for common tools such as Node, MongoDB, and Redis
* Utility scripts for common development tasks
* Gitignore templates for common stacks

---

## Setup

Clone the repository:

```
git clone https://github.com/livipi702/Dotfiles-.git
cd Dotfiles-
```

---

## Linking Configuration

The recommended approach is to symlink the configuration files:

```
ln -sf $(pwd)/.bashrc ~/.bashrc
ln -sf $(pwd)/.tmux.conf ~/.tmux.conf
ln -sf $(pwd)/nvim ~/.config/nvim
```

Reload the shell:

```
source ~/.bashrc
```

---

## Neovim

The Neovim configuration is based on lazy.nvim.

* Plugins are organized under `lua/plugins/`
* Configuration is modular and split by functionality
* `lazy-lock.json` ensures consistent plugin versions

Start Neovim:

```
nvim
```

---

## Setup Scripts

Scripts in `setup-scripts/` are used to install and configure development tools. These are exposed through aliases defined in `.bashrc`.

Examples include:

* Node installation
* MongoDB installation
* Redis installation
* Database setup
* Prompt configuration

---

## Utility Scripts

The `05-scripts/` directory contains reusable scripts and templates, including:

* Common aliases
* Log management utilities
* Git status helpers
* Cleanup scripts
* Gitignore templates for MERN and Spring Boot projects

---
