#!/usr/bin/env bash
# Verify one axis (SYS-006, 007 and 008) with Run42 for the controllers: an open-loop stepper, a closed-loop stepper and a
# brushless servo, each with a trapezoidal move and with a shaper tuned to its axis, and the open-loop stepper with a
# shaper tuned to the belt alone. Writes the verdicts, traces and plots into build/axis/. A failing verdict is
# a result, not an error of the script: a trapezoidal move on the open-loop stepper is expected to ring.
#
# Needs a Run42 installation that includes the Elan8 domain library with the stepper motor (a release package, or
# one assembled with scripts/assemble-package.sh), the Wasm target (`rustup target add wasm32-unknown-unknown`) and, from a
# source tree, SPEC42_STDLIB_ROOT and RUN42_ENGINES. Set RUN42 to the run42 executable.
set -uo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run42="${RUN42:?set RUN42 to the run42 executable}"
out="${repo}/build/axis"
mkdir -p "${out}"

bash "${repo}/firmware/axis-controller/build.sh" >/dev/null || exit 1
python3 "${repo}/scripts/generate_axis_drivers.py" >/dev/null
for controller in open-trapezoid open-shaped open-mistuned closed-trapezoid closed-shaped servo-trapezoid servo-shaped; do
  "${run42}" verify "${repo}/model" --driver "${repo}/verification/axis-${controller}.json" \
    --out "${out}/${controller}-verdicts.json" --trace-dir "${out}/${controller}" \
    --trace-signal carriage.s --trace-points 3001
done
exit 0
