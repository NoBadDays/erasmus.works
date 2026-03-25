#!/usr/bin/env bash

set -euo pipefail

request_file="kubernetes/apps/docmost/restore-drill/request.yaml"
kustomization_file="kubernetes/apps/docmost/kustomization.yaml"
restore_file="kubernetes/apps/docmost/restore-drill/restore.yaml"
restore_entry="  - restore-drill"

state="$(sed -n 's/^state:[[:space:]]*//p' "$request_file" | head -n1 | xargs)"
note="$(sed -n 's/^note:[[:space:]]*//p' "$request_file" | head -n1)"
note="${note#\"}"
note="${note%\"}"

case "$state" in
  idle|start|started|cleanup) ;;
  *)
    echo "Unsupported state: $state" >&2
    exit 1
    ;;
esac

if [[ "$state" == "idle" || "$state" == "started" ]]; then
  echo "changed=false" >> "$GITHUB_OUTPUT"
  echo "commit_message=Docmost restore drill: state already settled" >> "$GITHUB_OUTPUT"
  exit 0
fi

if [[ "$state" == "start" ]]; then
  if ! grep -Fxq "$restore_entry" "$kustomization_file"; then
    printf '%s\n' "$restore_entry" >> "$kustomization_file"
  fi

  trigger_value="restore-$(date -u +%Y%m%dT%H%M%SZ)"
  sed -i "s|^\([[:space:]]*manual:\).*|\1 $trigger_value|" "$restore_file"
  summary="start $trigger_value"
  next_state="started"
else
  temp_file="$(mktemp)"
  grep -Fvx "$restore_entry" "$kustomization_file" > "$temp_file" || true
  mv "$temp_file" "$kustomization_file"
  summary="cleanup"
  next_state="idle"
fi

escaped_note="${note//\\/\\\\}"
escaped_note="${escaped_note//\"/\\\"}"
printf 'state: %s\nnote: "%s"\n' "$next_state" "$escaped_note" > "$request_file"

if git diff --quiet; then
  echo "changed=false" >> "$GITHUB_OUTPUT"
else
  echo "changed=true" >> "$GITHUB_OUTPUT"
fi

if [[ -n "$note" ]]; then
  echo "commit_message=Docmost restore drill: $summary [$note]" >> "$GITHUB_OUTPUT"
else
  echo "commit_message=Docmost restore drill: $summary" >> "$GITHUB_OUTPUT"
fi
