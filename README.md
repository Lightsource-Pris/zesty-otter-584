# Assessment task template

The assessment task is how you join an Askable agentic coding project, such as **Frontier code** or
**TB4**. You build one small task end to end, in an afternoon: a real change to a real open-source
repo, graded by typed checks, with a wrong fix that those checks catch. It is a
[Harbor](https://docs.harborframework.com/tasks/overview) task, built in `task/`, checked locally,
then submitted as a pushed commit.

It is a Frontier code task without the heavy parts: no calibration ladder, no contamination dossier, no
difficulty run. What's left is what shows your judgement:

1. **An upstream repo at a base commit.** A real open-source repo, pinned to a commit on its default
   branch. The agent starts there.
2. **A change worth asking for.** A bug fix or small feature a maintainer would merge, described in
   `instruction.md` as an end state, not as steps.
3. **The golden patch.** `solution/golden.patch`: your own fix, applied by `solution/solve.sh`.
4. **A plausible wrong fix.** The fix a capable engineer or a strong coding agent could ship and
   believe is right, which your checks catch.
5. **The checks.** `tests/checks.toml`: what gets graded and how. The golden scores 1, doing nothing
   scores 0, the wrong fix fails a blocker.
6. **The rationale.** `docs/rationale.md`: one section per check, saying what it catches and why.
7. **The hack report.** `docs/hack-report.md`: the wrong fix and your other attempts to beat the
   checks, with their scores, and what you fixed.

The example in `task/` is a small, working task (add `max_length` to `textkit.slugify`) with all
seven. `textkit` is synthetic, so its source metadata is placeholders. Yours must build on a real
open-source repo. Replace the example with yours.

## Quick start

Your coding agent first fetches the grader into `task/tests/etask_grade.py` with the Askable MCP
tool `agentic_coding_get_grader` (see [AGENTS.md](AGENTS.md)). Then:

```bash
./setup.sh      # once: uv, pinned Harbor, Docker/Podman check, secrets into .env
./check.sh      # the golden (oracle) must score 1 and doing nothing (nop) must score 0
```

Your coding agent should read [AGENTS.md](AGENTS.md) first. It covers the task layout, the check
types, what makes a good task, how to score the wrong fix, and how to submit.

## An afternoon, roughly

| Time | Step |
| --- | --- |
| 30 min | Pick the repo, the base commit and the change. Get the repo building and its tests running in `environment/Dockerfile` |
| 45 min | Write the golden patch and `instruction.md` |
| 60 min | Write `tests/checks.toml` and the hidden reference tests; `./check.sh` until the golden scores 1 and nop 0 |
| 45 min | Write the wrong fix and two or three attacks, score each, tighten the checks; fill in `docs/hack-report.md` and `docs/rationale.md` |
| 15 min | Commit, push, submit |

## How grading works

`task/tests/checks.toml` is the task's rubric: typed checks (classical, command, reverse_classical,
scope, prompt). Each is a blocker or a weighted non-blocker. Any failed blocker scores 0; otherwise
the score is the weighted sum of passed checks. Deterministic checks run inside the task container
after the agent finishes. Prompt checks are judged by an LLM on the host.

Every check sees the agent's work as a diff against `base_ref` in `checks.toml`. Use one base
commit: `base_ref` equals `task.toml` `metadata.source.base_sha`, and the image starts clean at it,
so the nop agent's diff is empty. A non-empty nop diff makes the verifier refuse the task
(`invalid_task`). [AGENTS.md](AGENTS.md#what-a-good-task-looks-like) has a Dockerfile recipe that
fetches the pinned commit.

`task/tests/test.sh` is yours. After the checks run, the verifier runs it as written, and its exit
code becomes one more blocker check, `test-sh`: exit 0 to pass, anything else scores the task 0.
Put any tests that don't fit `checks.toml` there. Reward files it writes are ignored. The phase A
line it starts with grades `checks.toml` for a plain `harbor run` and skips itself under the
verifier and `./check.sh` (they set `ETASK_VERIFIER`); leave it in. `[verifier] timeout_sec` covers
the checks and `test.sh` together.

`./check.sh` grades the task the same way the Askable verifier does, with the verifier's grader in
`task/tests/etask_grade.py`. The grader isn't committed: your coding agent fetches the current one
with `agentic_coding_get_grader`, so grading fixes reach your local runs without a template change.
`./check.sh` prints the grader's sha256; when it differs from the tool's, fetch again. When you
submit, the verifier always grades with **its own** copy of `etask_grade.py`, never one from your
repo.

Prompt checks need an LLM key. Locally that's your own `ANTHROPIC_API_KEY` in `.env` (optional).
Without one they are skipped and `./check.sh` reports the run as incomplete (exit 3). When you
submit, Askable grades them.

## How verification works

When you submit, Askable's verifier
([agentic-coding-task-verifier](https://github.com/askablelabs-external/agentic-coding-task-verifier),
project `assessment_task`) runs on GitHub:

| Step | Pass condition | Local equivalent |
| --- | --- | --- |
| Validate | Layout, `task.contract.json`, canary, sizes, a valid `checks.toml` | `python3 task/tests/etask_grade.py validate` |
| Oracle and nop | The golden scores 1, doing nothing scores 0 and changes nothing | `./check.sh` |
| Quality review | A Claude Code reviewer scores the task against Askable's quality rubric: the brief, the checks, the wrong fix, the rationale and the hack report | None: it runs only in the verifier |

## Files at the root

| File | Purpose |
| --- | --- |
| `setup.sh` | Idempotent local setup. Secrets go only into the git-ignored `.env`. |
| `check.sh` | Runs the oracle and nop agents through Harbor and grades them. |
| `secrets.manifest.json` | Secrets the task needs: name, description, required. The Askable MCP reads it to tell your agent what to ask you for. |
| `task.contract.json` | Required files, size limits and required `task.toml` keys. The submission pre-check and the verifier enforce it. |
| `engineer-answers.toml` | Your answers to the two time questions: how long a focused expert would take, and how long the solving agent gets. You give them; your coding agent asks you and copies them into `task/task.toml`. `check.sh` stops until they are filled in and match. |
| `AGENTS.md` / `CLAUDE.md` | Guide for your coding agent. |

## Contract (`task.contract.json`)

| Key | Meaning |
| --- | --- |
| `schemaVersion` | Contract format version, currently `1`. |
| `taskDir` | Task directory relative to the repo root. `setup.sh` and `check.sh` expect `task`. |
| `requiredPaths` | Files that must exist in the task directory, on top of Harbor's five. |
| `managedPaths` | For reference: files the verifier never uses from your repo (it has its own copy). Editing them changes nothing. |
| `maxFileBytes` / `maxTaskBytes` | Size limits for any single file and the whole task directory. |
| `requiredTaskTomlKeys` | Dotted `task.toml` keys that must be present. |
| `canary` / `canaryPaths` | The training-data canary string and the files that must contain it. |
| `packageEvidence` | `false`: an assessment task has no `calibration/` attempts for the verifier to run. |

The verifier also holds its own copy of these rules. A repo's contract can only make them
stricter, never looser.

## Requirements

- Python 3.11+
- Docker, or Podman (macOS: `podman machine start`)
- uv (installed by `setup.sh` if missing)
