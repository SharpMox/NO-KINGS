#!/bin/sh
set -eu

# Regenerate the per-tool .<tool>/skills/ symlink farms that point back to
# .agents/skills/. Idempotent — safe to re-run after a fresh clone or after
# adding a tool or skill.
#
# Edit TOOLS to add/remove an agent CLI proxy. Edit SKILLS to change which
# skills are exposed. noodle/execute/schedule stay internal to .agents/skills/.

cd "$(dirname "$0")/.."

TOOLS="adal agent augment claude codebuddy commandcode continue cortex crush \
factory goose iflow junie kilocode kiro kode mcpjam mux neovate openhands \
pi pochi qoder qwen roo trae vibe windsurf zencoder"

SKILLS="godot-best-practices godot-gdscript-patterns godot-ui"

tools_count=0
skills_count=0

for tool in $TOOLS; do
  mkdir -p ".$tool/skills"
  for skill in $SKILLS; do
    [ -d ".agents/skills/$skill" ] || { echo "missing canonical skill: $skill" >&2; exit 1; }
    ln -sfn "../../.agents/skills/$skill" ".$tool/skills/$skill"
    skills_count=$((skills_count + 1))
  done
  tools_count=$((tools_count + 1))
done

echo "linked $skills_count symlinks ($tools_count tools × $(echo $SKILLS | wc -w | tr -d ' ') skills)"
