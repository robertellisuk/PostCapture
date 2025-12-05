#!/usr/bin/env bash
set -euo pipefail

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo "This script must be run as root (sudo)." >&2
        exit 1
    fi
}

stop_server() {
    local pid_file="$1"
    if [[ ! -f "${pid_file}" ]]; then
        echo "No PID file found; server may not be running."
        return
    fi

    local pid
    pid="$(<"${pid_file}")"
    if [[ -z "${pid}" ]]; then
        echo "PID file empty; removing."
        rm -f "${pid_file}"
        return
    fi

    if kill -0 "${pid}" 2>/dev/null; then
        echo "Stopping server process ${pid}..."
        kill "${pid}" || true
        sleep 1
        if kill -0 "${pid}" 2>/dev/null; then
            echo "Process still running; sending SIGKILL..."
            kill -9 "${pid}" || true
        fi
    else
        echo "No running process ${pid}; removing stale PID file."
    fi

    rm -f "${pid_file}"
}

restore_ufw() {
    local backup_dir="$1"
    local user_rules="${backup_dir}/user.rules.bak"
    local user6_rules="${backup_dir}/user6.rules.bak"

    if [[ ! -f "${user_rules}" || ! -f "${user6_rules}" ]]; then
        echo "UFW backup files missing; cannot restore automatically."
        return 1
    fi

    echo "Restoring UFW rules..."
    cp "${user_rules}" /etc/ufw/user.rules
    cp "${user6_rules}" /etc/ufw/user6.rules
    ufw reload >/dev/null
    echo "UFW restored from backups."
    return 0
}

main() {
    require_root

    local base_dir
    base_dir="$(cd "$(dirname "$0")" && pwd)"
    local backup_dir="${base_dir}/ufw-backup"
    local pid_file="${base_dir}/server.pid"

    stop_server "${pid_file}"
    restore_ufw "${backup_dir}" || true

    echo "Shutdown complete."
}

main "$@"
