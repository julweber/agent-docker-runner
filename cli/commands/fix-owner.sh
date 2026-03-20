# shellcheck shell=bash

cmd_fix_owner() {
    local target_dir="$PWD"
    local uid=""
    local gid=""

    if [[ $# -gt 0 ]]; then
        target_dir="$1"
    fi

    if [[ ! -d "$target_dir" ]]; then
        echo "Error: Directory does not exist: $target_dir" >&2
        exit 1
    fi

    uid=$(id -u)
    gid=$(id -g)

    if sudo chown -R "${uid}:${gid}" "$target_dir"; then
        echo "Changed ownership of all files in $target_dir to ${uid}:${gid}."
    else
        echo "Error: Failed to change ownership. Check sudo permissions and try again." >&2
        exit 1
    fi
}
