#!/bin/bash
# Runs the task the way the Askable verifier does: oracle must score 1, nop must score 0.
#   ./check.sh                              oracle and nop
#   ./check.sh --agent oracle               oracle only (score an attempt swapped into solution/)
#   ./check.sh --agent claude-code --model anthropic/claude-opus-5-5
set -euo pipefail
cd "$(dirname "$0")"

# The two time values are the engineer's answers in engineer-answers.toml, never the agent's guess.
check_engineer_answers() {
  python3 -I - <<'PY'
import sys

if sys.version_info < (3, 11):
    sys.exit("check.sh needs Python 3.11 or newer")
import tomllib

EXPERT_RANGE = None
AGENT_RANGE = None
QUESTIONS = (
    "Best case, how many hours would a focused expert who already knows this repository need to solve this task?"
    + (f" (expected {EXPERT_RANGE[0]} to {EXPERT_RANGE[1]})" if EXPERT_RANGE else ""),
    "How many hours should the solving agent get before it is stopped? The client runs the task with this"
    " budget, and an agent that runs out of time fails."
    + (f" (expected {AGENT_RANGE[0]} to {AGENT_RANGE[1]})" if AGENT_RANGE else ""),
)


def stop(problem):
    print(f"STOP: {problem}")
    print("These answers come from the engineer. If you are an AI agent, do not fill them in yourself: ask the")
    print("engineer, write down exactly what they say and their name, and quote it back to them:")
    for number, question in enumerate(QUESTIONS, 1):
        print(f"  {number}. {question}")
    sys.exit(2)


def hours(value):
    return value if isinstance(value, (int, float)) and not isinstance(value, bool) and value > 0 else None


def span(value):
    return f"{value:g} hour" + ("" if value == 1 else "s")


try:
    with open("engineer-answers.toml", "rb") as handle:
        answers = tomllib.load(handle)
except FileNotFoundError:
    stop("engineer-answers.toml is missing; restore it from the template.")
except tomllib.TOMLDecodeError as error:
    stop(f"engineer-answers.toml is not valid TOML ({error}).")

expert = hours(answers.get("expert_time_estimate_hours"))
agent = hours(answers.get("agent_timeout_hours"))
name = answers.get("answered_by")
if not (isinstance(name, str) and name.strip()) or expert is None or agent is None:
    stop("engineer-answers.toml is not filled in.")

try:
    with open("task/task.toml", "rb") as handle:
        task = tomllib.load(handle)
except (FileNotFoundError, tomllib.TOMLDecodeError) as error:
    print(f"FAIL task/task.toml can't be read, so the time values can't be checked ({error})")
    sys.exit(2)
wrong = []
if task.get("metadata", {}).get("expert_time_estimate_hours") != expert:
    wrong.append(f"metadata.expert_time_estimate_hours must be {expert} (the engineer's answer)")
timeout = task.get("agent", {}).get("timeout_sec")
if hours(timeout) is None or abs(timeout - agent * 3600) >= 0.5:
    wrong.append(f"[agent] timeout_sec must be {round(agent * 3600)} ({span(agent)}, the engineer's answer)")
if wrong:
    print("FAIL task/task.toml disagrees with engineer-answers.toml:")
    for line in wrong:
        print(f"  {line}")
    sys.exit(2)

for label, value, expected in (("expert estimate", expert, EXPERT_RANGE), ("agent time", agent, AGENT_RANGE)):
    if expected and not expected[0] <= value <= expected[1]:
        print(f"note: the {label} ({span(value)}) is outside {expected[0]} to {expected[1]} hours;"
              " check with the engineer that it is what they meant")
print(f"engineer answers ({name.strip()}): expert {span(expert)}, agent {span(agent)}")
PY
}
check_engineer_answers || exit $?

GRADER=task/tests/etask_grade.py
if [ ! -f "$GRADER" ]; then
  echo "check: $GRADER is missing. Ask your coding agent to fetch it with the Askable MCP tool agentic_coding_get_grader, then rerun." >&2
  exit 2
fi
exec python3 "$GRADER" check --task-dir task "$@"
