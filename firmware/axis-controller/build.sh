#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
# Build the variants of the axis controller for WebAssembly into build/axis-<name>.wasm:
#   open-trapezoid  open-loop stepper, no input shaper
#   open-shaped     open-loop stepper, a zero-vibration shaper tuned to the axis with the stepper's own stiffness, 62.08 Hz
#   open-mistuned   open-loop stepper, a shaper tuned to the belt alone, 69.02 Hz (the trade study's estimate)
#   closed-trapezoid, closed-shaped (63.5 Hz)   closed-loop stepper with an encoder and a position loop
#   servo-trapezoid, servo-shaped (61.5 Hz)     brushless servo with a position loop over a current loop
# Needs the wasm32-unknown-unknown target (`rustup target add wasm32-unknown-unknown`).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${here}"
mkdir -p "${here}/../../build"
build() { # name features
  cargo build --release --target wasm32-unknown-unknown ${2:+--features "$2"}
  cp target/wasm32-unknown-unknown/release/axis_controller.wasm "${here}/../../build/axis-$1.wasm"
}
build open-trapezoid ""
build open-shaped shaper6208
build open-mistuned shaper6902
build closed-trapezoid closed_loop
build closed-shaped closed_loop,shaper6350
build servo-trapezoid servo
build servo-shaped servo,shaper6150
ls -l "${here}/../../build"/axis-*.wasm
