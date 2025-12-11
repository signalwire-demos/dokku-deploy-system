#compdef dokku-cli
# ═══════════════════════════════════════════════════════════════════════════════
# Zsh completion for dokku-cli
# ═══════════════════════════════════════════════════════════════════════════════
#
# Installation:
#   # Add to fpath (before compinit in ~/.zshrc):
#   fpath=(/path/to/completions $fpath)
#
#   # Or copy to existing completion directory:
#   cp dokku-cli.zsh ~/.zsh/completions/_dokku-cli
#
#   # Then reload completions:
#   autoload -Uz compinit && compinit
#
# ═══════════════════════════════════════════════════════════════════════════════

_dokku_cli() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    local -a commands
    commands=(
        'setup:Configure CLI settings'
        'list:List all apps'
        'create:Create a new app'
        'destroy:Permanently delete an app'
        'info:Show app information'
        'logs:View app logs'
        'logs\:follow:Follow app logs in real-time'
        'config:Show environment variables'
        'config\:set:Set environment variables'
        'config\:unset:Remove environment variables'
        'restart:Restart app'
        'start:Start app'
        'stop:Stop app'
        'scale:View or set process scaling'
        'shell:Open interactive shell in app'
        'deploy:Deploy app via git push'
        'rollback:Rollback to previous release'
        'releases:List releases'
        'lock:Lock app (block deployments)'
        'unlock:Unlock app (allow deployments)'
        'lock\:status:Check lock status'
        'ssl:Manage SSL certificates'
        'domains:Manage domains'
        'db:Database operations'
        'run:Run one-off command'
        'alias:Manage app aliases'
        'i:Interactive mode (TUI)'
        'interactive:Interactive mode (TUI)'
        'pick:Pick an app interactively'
        'help:Show help'
        'version:Show version'
    )

    _arguments -C \
        '1: :->command' \
        '*: :->args'

    case $state in
        command)
            _describe -t commands 'dokku-cli commands' commands
            ;;
        args)
            case $words[2] in
                create|setup|list|help|version)
                    ;;
                ssl)
                    case $CURRENT in
                        3)
                            _dokku_cli_apps
                            ;;
                        4)
                            local -a ssl_actions
                            ssl_actions=('enable:Enable SSL' 'disable:Disable SSL' 'status:Check SSL status')
                            _describe -t ssl-actions 'SSL actions' ssl_actions
                            ;;
                    esac
                    ;;
                domains)
                    case $CURRENT in
                        3)
                            local -a domain_actions
                            domain_actions=('add:Add a domain' 'remove:Remove a domain')
                            _describe -t domain-actions 'Domain actions' domain_actions
                            ;;
                        4)
                            _dokku_cli_apps
                            ;;
                    esac
                    ;;
                db)
                    case $CURRENT in
                        3)
                            _dokku_cli_apps
                            ;;
                        4)
                            local -a db_actions
                            db_actions=(
                                'info:Show database info'
                                'create:Create and link database'
                                'connect:Connect to database shell'
                                'backup:Export database to local file'
                                'backup-server:Backup to server storage'
                                'restore:Restore from backup file'
                                'list-backups:List available backups'
                            )
                            _describe -t db-actions 'Database actions' db_actions
                            ;;
                        5)
                            case $words[4] in
                                create|connect|backup|backup-server|info)
                                    local -a services
                                    services=('postgres' 'mysql' 'redis' 'mongo' 'rabbitmq' 'elasticsearch')
                                    _describe -t services 'Database services' services
                                    ;;
                                restore)
                                    _files
                                    ;;
                            esac
                            ;;
                    esac
                    ;;
                deploy)
                    case $CURRENT in
                        3)
                            _dokku_cli_apps
                            ;;
                        4)
                            # Complete git branches
                            if git rev-parse --is-inside-work-tree &>/dev/null; then
                                local -a branches
                                branches=(${(f)"$(git branch -a 2>/dev/null | sed 's/^[* ]*//' | sed 's/remotes\/origin\///' | sort -u)"})
                                _describe -t branches 'Git branches' branches
                            fi
                            ;;
                    esac
                    ;;
                config:set|config:unset)
                    case $CURRENT in
                        3)
                            _dokku_cli_apps
                            ;;
                        *)
                            # Suggest KEY=value pattern
                            _message 'KEY=value'
                            ;;
                    esac
                    ;;
                run)
                    case $CURRENT in
                        3)
                            _dokku_cli_apps
                            ;;
                        *)
                            _command_names
                            ;;
                    esac
                    ;;
                *)
                    # Most commands take app name as second argument
                    if [[ $CURRENT -eq 3 ]]; then
                        _dokku_cli_apps
                    fi
                    ;;
            esac
            ;;
    esac
}

# Complete app names
_dokku_cli_apps() {
    local -a apps
    local cache_file="${HOME}/.dokku-cli-apps-cache"

    # Try cache first
    if [[ -f "$cache_file" ]] && [[ $(find "$cache_file" -mmin -60 2>/dev/null) ]]; then
        apps=(${(f)"$(cat $cache_file)"})
    else
        # Fetch from dashboard
        local json_apps
        json_apps=$(curl -s "https://signalwire-demos.github.io/dokku-deploy-system/apps.json" 2>/dev/null)
        if [[ -n "$json_apps" ]]; then
            apps=(${(f)"$(echo $json_apps | grep -o '"name":"[^"]*"' | cut -d'"' -f4)"})
            # Cache
            print -l $apps > "$cache_file"
        fi
    fi

    # Add aliases
    if [[ -f "${HOME}/.dokku-cli" ]]; then
        local -a aliases
        aliases=(${(f)"$(grep '^ALIAS_' ${HOME}/.dokku-cli 2>/dev/null | cut -d'=' -f1 | sed 's/ALIAS_//' | tr '[:upper:]' '[:lower:]')"})
        apps+=($aliases)
    fi

    _describe -t apps 'Dokku apps' apps
}

_dokku_cli "$@"
