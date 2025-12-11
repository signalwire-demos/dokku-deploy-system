# ═══════════════════════════════════════════════════════════════════════════════
# Fish completion for dokku-cli
# ═══════════════════════════════════════════════════════════════════════════════
#
# Installation:
#   cp dokku-cli.fish ~/.config/fish/completions/dokku-cli.fish
#
# ═══════════════════════════════════════════════════════════════════════════════

# Disable file completion by default
complete -c dokku-cli -f

# Helper function to get apps
function __dokku_cli_apps
    set -l cache_file "$HOME/.dokku-cli-apps-cache"

    # Check cache (less than 60 minutes old)
    if test -f "$cache_file"
        set -l age (math (date +%s) - (stat -f %m "$cache_file" 2>/dev/null; or stat -c %Y "$cache_file" 2>/dev/null))
        if test "$age" -lt 3600
            cat "$cache_file"
            return
        end
    end

    # Fetch from dashboard
    set -l apps (curl -s "https://signalwire-demos.github.io/dokku-deploy-system/apps.json" 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
    if test -n "$apps"
        printf '%s\n' $apps > "$cache_file"
        printf '%s\n' $apps
    end
end

# Helper function to get git branches
function __dokku_cli_branches
    if git rev-parse --is-inside-work-tree &>/dev/null
        git branch -a 2>/dev/null | sed 's/^[* ]*//' | sed 's/remotes\/origin\///' | sort -u
    end
end

# Commands
complete -c dokku-cli -n "__fish_use_subcommand" -a "setup" -d "Configure CLI settings"
complete -c dokku-cli -n "__fish_use_subcommand" -a "list" -d "List all apps"
complete -c dokku-cli -n "__fish_use_subcommand" -a "create" -d "Create a new app"
complete -c dokku-cli -n "__fish_use_subcommand" -a "destroy" -d "Permanently delete an app"
complete -c dokku-cli -n "__fish_use_subcommand" -a "info" -d "Show app information"
complete -c dokku-cli -n "__fish_use_subcommand" -a "logs" -d "View app logs"
complete -c dokku-cli -n "__fish_use_subcommand" -a "logs:follow" -d "Follow app logs in real-time"
complete -c dokku-cli -n "__fish_use_subcommand" -a "config" -d "Show environment variables"
complete -c dokku-cli -n "__fish_use_subcommand" -a "config:set" -d "Set environment variables"
complete -c dokku-cli -n "__fish_use_subcommand" -a "config:unset" -d "Remove environment variables"
complete -c dokku-cli -n "__fish_use_subcommand" -a "restart" -d "Restart app"
complete -c dokku-cli -n "__fish_use_subcommand" -a "start" -d "Start app"
complete -c dokku-cli -n "__fish_use_subcommand" -a "stop" -d "Stop app"
complete -c dokku-cli -n "__fish_use_subcommand" -a "scale" -d "View or set process scaling"
complete -c dokku-cli -n "__fish_use_subcommand" -a "shell" -d "Open interactive shell in app"
complete -c dokku-cli -n "__fish_use_subcommand" -a "deploy" -d "Deploy app via git push"
complete -c dokku-cli -n "__fish_use_subcommand" -a "rollback" -d "Rollback to previous release"
complete -c dokku-cli -n "__fish_use_subcommand" -a "releases" -d "List releases"
complete -c dokku-cli -n "__fish_use_subcommand" -a "lock" -d "Lock app (block deployments)"
complete -c dokku-cli -n "__fish_use_subcommand" -a "unlock" -d "Unlock app (allow deployments)"
complete -c dokku-cli -n "__fish_use_subcommand" -a "lock:status" -d "Check lock status"
complete -c dokku-cli -n "__fish_use_subcommand" -a "ssl" -d "Manage SSL certificates"
complete -c dokku-cli -n "__fish_use_subcommand" -a "domains" -d "Manage domains"
complete -c dokku-cli -n "__fish_use_subcommand" -a "db" -d "Database operations"
complete -c dokku-cli -n "__fish_use_subcommand" -a "run" -d "Run one-off command"
complete -c dokku-cli -n "__fish_use_subcommand" -a "alias" -d "Manage app aliases"
complete -c dokku-cli -n "__fish_use_subcommand" -a "i" -d "Interactive mode (TUI)"
complete -c dokku-cli -n "__fish_use_subcommand" -a "interactive" -d "Interactive mode (TUI)"
complete -c dokku-cli -n "__fish_use_subcommand" -a "pick" -d "Pick an app interactively"
complete -c dokku-cli -n "__fish_use_subcommand" -a "help" -d "Show help"
complete -c dokku-cli -n "__fish_use_subcommand" -a "version" -d "Show version"

# App completion for commands that take app as second arg
complete -c dokku-cli -n "__fish_seen_subcommand_from info logs logs:follow config restart start stop scale shell rollback releases lock unlock lock:status destroy" -a "(__dokku_cli_apps)" -d "App"

# SSL subcommands
complete -c dokku-cli -n "__fish_seen_subcommand_from ssl" -a "(__dokku_cli_apps)" -d "App"
complete -c dokku-cli -n "__fish_seen_subcommand_from ssl; and __fish_is_token_n 3" -a "enable disable status" -d "Action"

# Domains subcommands
complete -c dokku-cli -n "__fish_seen_subcommand_from domains; and __fish_is_token_n 2" -a "add remove" -d "Action"
complete -c dokku-cli -n "__fish_seen_subcommand_from domains; and __fish_is_token_n 3" -a "(__dokku_cli_apps)" -d "App"

# DB subcommands
complete -c dokku-cli -n "__fish_seen_subcommand_from db; and __fish_is_token_n 2" -a "(__dokku_cli_apps)" -d "App"
complete -c dokku-cli -n "__fish_seen_subcommand_from db; and __fish_is_token_n 3" -a "info create connect backup backup-server restore list-backups" -d "Action"
complete -c dokku-cli -n "__fish_seen_subcommand_from db; and __fish_is_token_n 4" -a "postgres mysql redis mongo rabbitmq elasticsearch" -d "Service"

# Deploy - complete branches
complete -c dokku-cli -n "__fish_seen_subcommand_from deploy; and __fish_is_token_n 2" -a "(__dokku_cli_apps)" -d "App"
complete -c dokku-cli -n "__fish_seen_subcommand_from deploy; and __fish_is_token_n 3" -a "(__dokku_cli_branches)" -d "Branch"

# Config set/unset
complete -c dokku-cli -n "__fish_seen_subcommand_from config:set config:unset; and __fish_is_token_n 2" -a "(__dokku_cli_apps)" -d "App"
