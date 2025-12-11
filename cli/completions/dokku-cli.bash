# ═══════════════════════════════════════════════════════════════════════════════
# Bash completion for dokku-cli
# ═══════════════════════════════════════════════════════════════════════════════
#
# Installation:
#   # Linux
#   sudo cp dokku-cli.bash /etc/bash_completion.d/dokku-cli
#
#   # macOS (with Homebrew)
#   cp dokku-cli.bash $(brew --prefix)/etc/bash_completion.d/dokku-cli
#
#   # Or add to ~/.bashrc:
#   source /path/to/dokku-cli.bash
#
# ═══════════════════════════════════════════════════════════════════════════════

_dokku_cli_completions() {
    local cur prev words cword
    _init_completion || return

    # All available commands
    local commands="setup doctor list create destroy info logs logs:follow config config:set config:unset restart start stop scale shell deploy rollback releases lock unlock lock:status ssl domains db run alias i interactive pick help version"

    # Subcommands for specific commands
    local ssl_actions="enable disable status"
    local domains_actions="add remove"
    local db_actions="info create connect backup backup-server restore list-backups"
    local services="postgres mysql redis mongo rabbitmq elasticsearch"

    # Get the command (first non-option argument after dokku-cli)
    local cmd=""
    local i
    for ((i=1; i < cword; i++)); do
        if [[ "${words[i]}" != -* ]]; then
            cmd="${words[i]}"
            break
        fi
    done

    case "$cword" in
        1)
            # Complete commands
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
            ;;
        2)
            # Complete based on command
            case "$cmd" in
                ssl)
                    # Could be app name or action
                    COMPREPLY=($(compgen -W "$ssl_actions" -- "$cur"))
                    ;;
                domains)
                    COMPREPLY=($(compgen -W "$domains_actions" -- "$cur"))
                    ;;
                db)
                    # First arg is app name, try to complete from cache
                    _dokku_cli_complete_apps
                    ;;
                create|setup|list|help|version)
                    # No completion needed
                    ;;
                *)
                    # Most commands take an app name as second arg
                    _dokku_cli_complete_apps
                    ;;
            esac
            ;;
        3)
            case "$cmd" in
                ssl)
                    # ssl <app> <action>
                    COMPREPLY=($(compgen -W "$ssl_actions" -- "$cur"))
                    ;;
                domains)
                    # domains <action> <app>
                    _dokku_cli_complete_apps
                    ;;
                db)
                    # db <app> <action>
                    COMPREPLY=($(compgen -W "$db_actions" -- "$cur"))
                    ;;
                rollback)
                    # rollback <app> <version> - no completion for version
                    ;;
                config:set|config:unset)
                    # Could suggest KEY= pattern
                    ;;
                deploy)
                    # deploy <app> <branch> - complete git branches
                    _dokku_cli_complete_branches
                    ;;
                lock)
                    # lock <app> <reason> - no completion for reason
                    ;;
            esac
            ;;
        4)
            case "$cmd" in
                db)
                    # db <app> <action> <service>
                    local action="${words[3]}"
                    case "$action" in
                        create|connect|backup|backup-server|info)
                            COMPREPLY=($(compgen -W "$services" -- "$cur"))
                            ;;
                        restore)
                            # Complete file paths for restore
                            _filedir
                            ;;
                    esac
                    ;;
            esac
            ;;
    esac
}

# Complete app names from cache or server
_dokku_cli_complete_apps() {
    local apps=""

    # Try to get from cache first (faster)
    local cache_file="${HOME}/.dokku-cli-apps-cache"
    if [[ -f "$cache_file" && $(find "$cache_file" -mmin -60 2>/dev/null) ]]; then
        apps=$(cat "$cache_file")
    else
        # Try to fetch from dashboard
        apps=$(curl -s "https://signalwire-demos.github.io/dokku-deploy-system/apps.json" 2>/dev/null | \
            grep -o '"name":"[^"]*"' | cut -d'"' -f4)

        # Cache if successful
        if [[ -n "$apps" ]]; then
            echo "$apps" > "$cache_file"
        fi
    fi

    # Also check for aliases
    local aliases=""
    if [[ -f "${HOME}/.dokku-cli" ]]; then
        aliases=$(grep "^ALIAS_" "${HOME}/.dokku-cli" 2>/dev/null | cut -d'=' -f1 | sed 's/ALIAS_//' | tr '[:upper:]' '[:lower:]')
    fi

    COMPREPLY=($(compgen -W "$apps $aliases" -- "$cur"))
}

# Complete git branch names
_dokku_cli_complete_branches() {
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        local branches=$(git branch -a 2>/dev/null | sed 's/^[* ]*//' | sed 's/remotes\/origin\///' | sort -u)
        COMPREPLY=($(compgen -W "$branches" -- "$cur"))
    fi
}

# Register completion
complete -F _dokku_cli_completions dokku-cli
