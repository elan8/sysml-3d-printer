#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
# Run every check of the repository and print one summary.
#
#   bash scripts/verify-all.sh            # the public checks only
#   bash scripts/verify-all.sh --run42    # also the simulations; needs RUN42, see below
#
# Public checks (free tools): the Spec42 validation, the unit tests (trade study, generated files, axis design), the
# Modelica reference cases of the plant (needs the GitHub CLI and ELAN8_MODELICA, see the README) and `doc42 check` if
# doc42 is installed. A step whose tool is missing is reported as SKIP, never as a pass.
#
# Simulation checks (--run42): the axis, CoreXY, hotend and supervisor verification with Run42, and then the generated
# reports. The reports are committed, so the last step fails if a fresh run changed them: the committed results no longer
# match the model, the firmware or the plant. Set RUN42 to the run42 executable; the reports need numpy and matplotlib,
# and the Run42 release must include the domain library the model pins (a mismatched build fails the cases with an error). A failing verdict of a case that is
# expected to fail (a trapezoidal move on the open-loop stepper) is a result, not an error.
#
# The exit status is 1 if any step failed.
set -uo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo}"

simulate=false
for argument in "$@"; do
  case "${argument}" in
    --run42) simulate=true ;;
    -h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown argument: ${argument}" >&2; exit 2 ;;
  esac
done

names=()
results=()
failed=0

record() { names+=("$1"); results+=("$2"); [[ "$2" == FAIL ]] && failed=1; return 0; }

# step <name> <command...>: run it, show its output only if it fails.
step() {
  local name="$1"; shift
  local log; log="$(mktemp)"
  if "$@" >"${log}" 2>&1; then
    record "${name}" PASS
  else
    record "${name}" FAIL
    echo "--- ${name} failed ---"; tail -n 25 "${log}"; echo "---"
  fi
  rm -f "${log}"
}

skip() { record "$1 ($2)" SKIP; }

# A digest of everything the generators may rewrite, to see whether a fresh run changed it.
generated_state() { git status --porcelain -- docs model/80_documents | sort | sha256sum; git diff -- docs model/80_documents | sha256sum; }

echo "== Public checks =="
step "Spec42 validation" python3 scripts/validate_spec42.py
step "Unit tests" python3 -B -m unittest discover -s tests

if command -v gh >/dev/null 2>&1 && [[ -n "${ELAN8_MODELICA:-}" ]]; then
  step "Modelica reference cases" bash tests/modelica/run.sh
else
  skip "Modelica reference cases" "needs gh and ELAN8_MODELICA"
fi

if command -v doc42 >/dev/null 2>&1; then
  step "doc42 check" doc42 check model --workspace-root .
else
  skip "doc42 check" "doc42 not installed"
fi

if ${simulate}; then
  echo "== Simulations =="
  if [[ -z "${RUN42:-}" || ! -x "${RUN42}" ]]; then
    record "Run42 simulations (RUN42 is not set to an executable)" FAIL
  else
    before="$(generated_state)"
    step "Axis verification" bash scripts/verify_axis.sh
    if [[ -f scripts/check_axis_verdicts.py ]]; then
      step "Axis verdict pattern" python3 scripts/check_axis_verdicts.py build/axis
    fi
    step "CoreXY verification" python3 scripts/verify_corexy.py
    step "Hotend verification" python3 scripts/verify_hotend.py
    step "Supervisor verification" python3 scripts/verify_supervisor.py
    step "Verification report" python3 scripts/write_verification_report.py
    step "CoreXY report" python3 scripts/report_corexy.py
    step "Hotend report" python3 scripts/report_hotend.py
    if [[ "$(generated_state)" == "${before}" ]]; then
      record "Committed results match a fresh run" PASS
    else
      record "Committed results match a fresh run (see git diff)" FAIL
    fi
  fi
else
  skip "Simulations" "run with --run42"
fi

echo
echo "== Summary =="
for i in "${!names[@]}"; do
  printf '%-4s  %s\n' "${results[$i]}" "${names[$i]}"
done
if [[ ${failed} -eq 0 ]]; then echo "All steps that ran passed."; else echo "At least one step failed."; fi
exit ${failed}
