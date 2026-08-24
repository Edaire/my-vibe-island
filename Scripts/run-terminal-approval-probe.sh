#!/bin/zsh
set -euo pipefail

if (( $# != 3 )); then
    print -u2 "usage: $0 <session-id> <turn-id> <output-path>"
    exit 64
fi

session_id="$1"
turn_id="$2"
output_path="$3"
repo_root="${0:A:h:h}"
hook="$repo_root/.build/debug/my-vibe-island-hooks"
socket_path="$HOME/.my-vibe-island/run/my-vibe-island.sock"
cwd="/tmp/codex-approval-probe"
prompt="Do not modify any files. Request approval before running the harmless command /usr/bin/whoami, then stop."

sleep 2
printf '{"session_id":"%s","cwd":"%s","hook_event_name":"SessionStart"}' "$session_id" "$cwd" |
    "$hook" --source codex --event SessionStart --socket "$socket_path" >/dev/null
printf '{"session_id":"%s","turn_id":"%s","cwd":"%s","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "$session_id" "$turn_id" "$cwd" "$prompt" |
    "$hook" --source codex --event UserPromptSubmit --socket "$socket_path" >/dev/null
"$hook" --source codex --event PermissionRequest --socket "$socket_path" --input \
    "{\"session_id\":\"$session_id\",\"turn_id\":\"$turn_id\",\"cwd\":\"$cwd\",\"hook_event_name\":\"PermissionRequest\",\"permission_mode\":\"default\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"/usr/bin/whoami\",\"description\":\"Do you approve running the harmless command /usr/bin/whoami?\"}}" \
    >"$output_path" 2>&1
