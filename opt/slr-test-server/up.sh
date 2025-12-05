#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: sudo $0 <PORT> <PATH>" >&2
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo "This script must be run as root (sudo)." >&2
        exit 1
    fi
}

main() {
    require_root

    if [[ $# -ne 2 ]]; then
        usage
        exit 1
    fi

    local port="$1"
    local allowed_path="$2"

    if ! [[ "${port}" =~ ^[0-9]+$ ]]; then
        echo "Port must be an integer." >&2
        exit 1
    fi

    local base_dir
    base_dir="$(cd "$(dirname "$0")" && pwd)"
    local backup_dir="${base_dir}/ufw-backup"
    local pid_file="${base_dir}/server.pid"
    local log_file="${base_dir}/server.log"

    mkdir -p "${backup_dir}"

    echo "Backing up UFW rule files..."
    cp /etc/ufw/user.rules "${backup_dir}/user.rules.bak"
    cp /etc/ufw/user6.rules "${backup_dir}/user6.rules.bak"

    echo "Allowing TCP port ${port} via UFW..."
    ufw allow "${port}"/tcp comment 'slr-test-server' >/dev/null
    ufw reload >/dev/null

    echo "Starting HTTP server on port ${port} (path: ${allowed_path})..."
    python3 "${base_dir}/server.py" --port "${port}" --path "${allowed_path}" \
        >"${log_file}" 2>&1 &
    local pid=$!
    echo "${pid}" >"${pid_file}"

    echo "Server started with PID ${pid}. Logs: ${log_file}"
    echo "Setup complete."
}

main "$@"
