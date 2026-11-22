#!/usr/bin/env bash
# Compiles and simulates the axis models (AxisTests.mo) with rumoca and checks the results against references derived
# without a simulator (check.py). Needs the Elan8 domain library's Modelica package (the `Elan8/` directory of the
# release's Modelica archive, with the StepperMotor class): set ELAN8_MODELICA to the directory that holds it.
# Downloads the pinned rumoca release and the Modelica Standard Library into tests/modelica/.cache on first use;
# needs the GitHub CLI (`gh`) and Linux x86_64.
set -euo pipefail

RUMOCA_VERSION=v0.10.4
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elan8="${ELAN8_MODELICA:?set ELAN8_MODELICA to the directory that holds the Elan8 domain library Modelica package (Elan8/)}"
[[ -f "$elan8/Elan8/package.mo" ]] || { echo "$elan8/Elan8/package.mo not found" >&2; exit 1; }
MSL_NUMBER="$(sed -n 's/.*uses(Modelica(version *= *"\([0-9.]*\)")).*/\1/p' "$elan8/Elan8/package.mo")"
[[ -n "$MSL_NUMBER" ]] || { echo "$elan8/Elan8/package.mo declares no uses(Modelica(version=...))" >&2; exit 1; }
MSL_VERSION="v$MSL_NUMBER"
cache="$here/.cache"
out="$here/out"
mkdir -p "$cache" "$out"

rumoca="$cache/rumoca-$RUMOCA_VERSION"
if [[ ! -x "$rumoca" ]]; then
  gh release download "$RUMOCA_VERSION" -R CogniPilot/rumoca -p rumoca-linux-x86_64 -O "$rumoca" --clobber
  chmod +x "$rumoca"
fi
msl="$cache/msl-$MSL_VERSION"
if [[ ! -d "$msl" ]]; then
  gh release download "$MSL_VERSION" -R modelica/ModelicaStandardLibrary \
    -p "ModelicaStandardLibrary_${MSL_VERSION}.zip" -O "$cache/msl.zip" --clobber
  unzip -q "$cache/msl.zip" -d "$msl"
fi
roots=(--source-root "$elan8/Elan8" --source-root "$msl/Modelica $MSL_NUMBER"
       --source-root "$msl/Complex.mo" --source-root "$msl/ModelicaServices $MSL_NUMBER")
tol=(--rtol 1e-9 --atol 1e-12)

"$rumoca" --version
sim() { # model output-step
  "$rumoca" sim "$here/AxisTests.mo" -m "AxisTests.$1" "${roots[@]}" "${tol[@]}" --dt "$2" -o "$out/$1.csv"
}
sim AxisBeltOnly 1e-5
sim AxisStepperHold 1e-5

python3 "$here/check.py" "$out"
