#!/usr/bin/env bash

###############################################################################
# Database Management Toolkit
###############################################################################

declare -A DB_UNITS=(
    [mongo]="mongod"
    [redis]="redis-server"
    [postgres]="postgresql"
)

declare -A DB_PORTS=(
    [mongo]=27017
    [redis]=6379
    [postgres]=5432
)

declare -A DB_ALIASES=(
    [mg]="mongo"
    [rd]="redis"
    [pg]="postgres"
)

DB_SERVICES=(mongo redis postgres)

###############################################################################
# Internal Utilities
###############################################################################

_db::resolve() {
    local key="$1"
    if [[ -n "${DB_UNITS[$key]+_}" ]]; then echo "$key"; return 0; fi
    local canon="${DB_ALIASES[$key]:-}"
    if [[ -n "$canon" && -n "${DB_UNITS[$canon]+_}" ]]; then echo "$canon"; return 0; fi
    return 1
}

_db::running() { systemctl is-active --quiet "$1" 2>/dev/null; }

_db::port_open() {
    ss -ltn 2>/dev/null | grep -qE ":${1}[[:space:]]"
}

_db::port_info() {
    sudo ss -ltnp 2>/dev/null | grep -E ":${1}[[:space:]]"
}

_db::header() {
    printf '\n  \e[1m%s\e[0m\n  %s\n\n' "$1" "$(printf '─%.0s' {1..56})"
}

_db::ok()   { printf '  \e[32m✔\e[0m %s\n' "$*"; }
_db::warn() { printf '  \e[33m⚠\e[0m %s\n' "$*"; }
_db::err()  { printf '  \e[31m✖\e[0m %s\n' "$*"; }
_db::info() { printf '  \e[36mℹ\e[0m %s\n' "$*"; }

_db::status_lines() {
    local unit="$1" lines="${2:-3}"
    systemctl status "$unit" --no-pager -n "$lines" 2>&1 \
        | grep -vE '^\s+(Docs:|man:|https?://)' \
        | sed 's/^/    /'
}

_db::config_path() {
    case "$1" in
        mongod)       echo "/etc/mongod.conf" ;;
        redis-server) echo "/etc/redis/redis.conf" ;;
        postgresql)   find /etc/postgresql -name postgresql.conf 2>/dev/null | head -n 1 ;;
    esac
}

_db::ping() {
    case "$1" in
        mongo)
            local client
            client=$(command -v mongosh 2>/dev/null \
                  || command -v mongo  2>/dev/null) || return 1
            "$client" --quiet --eval "db.adminCommand({ping:1})" &>/dev/null
            ;;
        redis)
            command -v redis-cli &>/dev/null || return 1
            [[ "$(redis-cli ping 2>/dev/null)" == "PONG" ]]
            ;;
        postgres)
            command -v pg_isready &>/dev/null || return 1
            pg_isready -q 2>/dev/null
            ;;
        *) return 1 ;;
    esac
}

_db::require_systemd() {
    if [[ ! -d /run/systemd/system ]]; then
        _db::err "systemd is not running"
        _db::info "Add to /etc/wsl.conf:  [boot]  systemd=true"
        return 1
    fi
}

###############################################################################
# Help
###############################################################################

db::help() {
    cat <<'HELP'

  Database Management Toolkit

  Usage:  db <service> <command> [args]

  Services:
    mongo (mg)
    redis (rd)
    postgres (pg)
    all

  Commands:
    start
    stop
    restart
    status
    logs
    config
    port
    health
    enable
    disable
    clean-logs [N]

  Global:
    db versions
    db help

HELP
}

###############################################################################
# Actions
###############################################################################

_db::action() {
    local name="$1" cmd="$2"
    local unit="${DB_UNITS[$name]}"
    local port="${DB_PORTS[$name]}"

    case "$cmd" in
        start)
            if _db::running "$unit"; then
                _db::ok "$name is already running"
            else
                sudo systemctl start "$unit" \
                    && _db::ok  "Started $name" \
                    || { _db::err "Failed to start $name"; return 1; }
            fi
            _db::status_lines "$unit" 0
            ;;

        stop)
            if _db::running "$unit"; then
                sudo systemctl stop "$unit" \
                    && _db::ok  "Stopped $name" \
                    || { _db::err "Failed to stop $name"; return 1; }
            else
                _db::warn "$name is already stopped"
            fi
            _db::status_lines "$unit" 0
            ;;

        restart)
            sudo systemctl restart "$unit" \
                && _db::ok  "Restarted $name" \
                || { _db::err "Failed to restart $name"; return 1; }
            _db::status_lines "$unit" 0
            ;;

        status)
            _db::header "Status: $name ($unit)"
            _db::status_lines "$unit" 5
            ;;

        logs)
            _db::header "Logs: $name"
            sudo journalctl -u "$unit" -f --no-hostname
            ;;

        config)
            local path
            path=$(_db::config_path "$unit")
            _db::header "Config: $name"
            if [[ -n "$path" && -f "$path" ]]; then
                _db::info "Path: $path"
                echo
                sed 's/^/    /' "$path"
            else
                _db::warn "Config not found${path:+ at $path}"
            fi
            ;;

        port)
            _db::header "Port: $name → $port"
            if _db::port_open "$port"; then
                _db::ok "Port $port is listening"
                echo
                _db::port_info "$port" | sed 's/^/    /'
            else
                _db::warn "Port $port is not listening"
            fi
            ;;

        health)
            _db::header "Health: $name"

            _db::running "$unit" \
                && _db::ok  "service: active" \
                || _db::err "service: inactive"

            _db::port_open "$port" \
                && _db::ok   "port $port: listening" \
                || _db::warn "port $port: not listening"

            _db::ping "$name" \
                && _db::ok   "connect: responding" \
                || _db::warn "connect: no response"

            local errs
            errs=$(sudo journalctl -u "$unit" -n 50 --no-pager 2>/dev/null \
                   | grep -Eic 'fatal|error|fail' || true)

            if [[ "${errs:-0}" -gt 0 ]]; then
                _db::warn "logs: $errs error(s) in last 50 entries"
            else
                _db::ok  "logs: no recent errors"
            fi

            systemctl is-enabled --quiet "$unit" 2>/dev/null \
                && _db::info "boot: enabled" \
                || _db::info "boot: disabled"
            echo
            ;;

        enable)
            sudo systemctl enable "$unit" 2>/dev/null \
                && _db::ok  "Enabled $name on boot" \
                || _db::err "Failed to enable $name"
            ;;

        disable)
            sudo systemctl disable "$unit" 2>/dev/null \
                && _db::ok  "Disabled $name on boot" \
                || _db::err "Failed to disable $name"
            ;;

        clean-logs)
            local days="$3"
            local before after vacuum_arg

            before=$(sudo journalctl -u "$unit" --no-pager 2>/dev/null | wc -l)

            if [[ -n "$days" ]]; then
                if [[ "$days" =~ ^[0-9]+$ ]]; then
                    vacuum_arg="--vacuum-time=${days}d"
                    _db::header "Cleaning logs: $name (older than $days days)"
                else
                    _db::err "Invalid argument '$days'. Must be a number."
                    return 1
                fi
            else
                vacuum_arg="--vacuum-time=1s"
                _db::header "Wiping ALL logs: $name"
                sudo journalctl --rotate &>/dev/null
            fi

            sudo journalctl "$vacuum_arg" &>/dev/null

            after=$(sudo journalctl -u "$unit" --no-pager 2>/dev/null | wc -l)

            _db::ok "Cleanup complete"
            _db::info "Unit entries: $before → $after lines"
            ;;

        *)
            _db::err "Unknown command: '$cmd'"
            db::help
            return 1
            ;;
    esac
}

###############################################################################
# Versions
###############################################################################

_db::versions() {
    _db::header "Installed Versions"

    if command -v mongod &>/dev/null; then
        _db::ok "MongoDB:    $(mongod --version 2>/dev/null | head -n1)"
    else
        _db::warn "MongoDB:    not installed"
    fi

    if command -v redis-server &>/dev/null; then
        _db::ok "Redis:      $(redis-server --version 2>/dev/null)"
    else
        _db::warn "Redis:      not installed"
    fi

    if command -v psql &>/dev/null; then
        _db::ok "PostgreSQL: $(psql --version 2>/dev/null)"
    else
        _db::warn "PostgreSQL: not installed"
    fi
    echo
}

###############################################################################
# Main Dispatch
###############################################################################

db() {
    local svc="${1:-}" cmd="${2:-status}"

    if [[ -z "$svc" ]]; then db::help; return 0; fi

    case "$svc" in
        help|--help|-h) db::help; return 0 ;;
        versions|-v)    _db::versions; return 0 ;;
    esac

    _db::require_systemd || return 1

    if [[ "$svc" == "all" ]]; then
        local rc=0
        for s in "${DB_SERVICES[@]}"; do
            _db::action "$s" "$cmd" "$3" || rc=1
        done
        return "$rc"
    fi

    local canon
    canon=$(_db::resolve "$svc") || {
        _db::err "Unknown service: '$svc'"
        _db::info "Available: mongo (mg) | redis (rd) | postgres (pg) | all"
        return 1
    }

    _db::action "$canon" "$cmd" "$3"
}

###############################################################################
# Aliases & Completion
###############################################################################

alias mg='db mongo'
alias rd='db redis'
alias pg='db postgres'

_db_completions() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local cmd="${COMP_WORDS[0]}"

    local services="mongo mg redis rd postgres pg all"
    local actions="start stop restart status logs config port health enable disable clean-logs"
    local globals="versions help"

    if [[ -n "${DB_ALIASES[$cmd]+_}" ]]; then
        case "$COMP_CWORD" in
            1) COMPREPLY=($(compgen -W "$actions" -- "$cur")) ;;
        esac
        return
    fi

    case "$COMP_CWORD" in
        1)
            COMPREPLY=($(compgen -W "$services $globals" -- "$cur"))
            ;;
        2)
            local prev="${COMP_WORDS[1]}"
            if _db::resolve "$prev" &>/dev/null || [[ "$prev" == "all" ]]; then
                COMPREPLY=($(compgen -W "$actions" -- "$cur"))
            fi
            ;;
    esac
}

if [[ -n "${BASH_VERSION:-}" ]]; then
    complete -F _db_completions db
    complete -F _db_completions mg rd pg
fi

###############################################################################
# End
###############################################################################
