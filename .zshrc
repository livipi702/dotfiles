# ── Zinit ─────────────────────────────────────────────────────────────────────
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
   echo "[zinit] Bootstrapping..."
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
[[ -r "$ZINIT_HOME/zinit.zsh" ]] && source "$ZINIT_HOME/zinit.zsh"

# ── Plugins ───────────────────────────────────────────────────────────────────
zinit ice wait lucid
zinit light zsh-users/zsh-autosuggestions
zinit ice wait lucid
zinit light zsh-users/zsh-completions

# ── Completions ───────────────────────────────────────────────────────────────
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
   compinit -i
else
   compinit -Ci
fi

# ── History ───────────────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY

# ── Options ───────────────────────────────────────────────────────────────────
setopt AUTO_CD
unsetopt CORRECT
setopt NO_BEEP
setopt INTERACTIVE_COMMENTS
WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'

# ── PATH ──────────────────────────────────────────────────────────────────────
add_to_path() {
   case ":$PATH:" in
     *":$1:"*) ;;
     *) export PATH="$1:$PATH" ;;
   esac
}

add_to_path "$HOME/.local/bin"

# pnpm
export PNPM_HOME="/home/aryan/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end

export MISE_GITHUB_TOKEN=""

# ── mise (early: all tools below depend on it) ────────────────────────────────
if command -v mise >/dev/null; then
   eval "$(mise activate zsh --no-hook-env)"
   autoload -Uz add-zsh-hook
   _mise_light_chpwd() { eval "$(mise hook-env -s zsh)"; }
   add-zsh-hook chpwd _mise_light_chpwd
   eval "$(mise hook-env -s zsh)"
fi

# ── Editor ────────────────────────────────────────────────────────────────────
export EDITOR=nvim
export VISUAL=nvim

# ── Aliases ───────────────────────────────────────────────────────────────────
alias ls='eza --icons=auto'
alias ll='eza -alF --icons=auto --git'
alias la='eza -a --icons=auto'
alias l='eza -F --icons=auto'
alias tree='eza --tree --icons=auto --git-ignore'

alias bcat='bat --paging=never'
alias bless='bat --paging=always'

alias vi='nvim'

alias top='btop'
alias htop='btop'

alias lg='lazygit'

alias now='date "+%A, %d %B %Y - %I:%M:%S %p %Z"'

alias vij='NVIM_APPNAME=nvim-java nvim'

# ── fzf key bindings (before atuin so atuin keeps Ctrl-R) ───────────
if [ -s "$HOME/.fzf.zsh" ]; then
   source ~/.fzf.zsh
else
   for _ex in /usr/share/doc/fzf/examples/completion.zsh \
               /usr/share/doc/fzf/examples/key-bindings.zsh; do
      [ -r "$_ex" ] && source "$_ex"
   done
   unset _ex
fi

# ── Tool integrations ─────────────────────────────────────────────────────────
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(atuin init zsh)"

export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'


# ── Setup script aliases ──────────────────────────────────────────────────────
[ -x "$HOME/setup-scripts/concat.sh" ]        && alias concat="$HOME/setup-scripts/concat.sh"
[ -x "$HOME/setup-scripts/git2ai.py" ]        && alias git2ai="$HOME/setup-scripts/git2ai.py"
[ -x "$HOME/setup-scripts/clean-modules.sh" ] && alias rm-modules="$HOME/setup-scripts/clean-modules.sh"
[ -f "$HOME/setup-scripts/git.sh" ]                     && source "$HOME/setup-scripts/git.sh"


