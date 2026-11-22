#!/usr/bin/env bash
# Build the three variants of the axis controller for WebAssembly into build/:
#   axis-trapezoid.wasm  no input shaper
#   axis-shaped.wasm     a zero-vibration shaper tuned to the axis with the stepper's own stiffness, 62.08 Hz
#   axis-mistuned.wasm   a shaper tuned to the belt alone, 69.02 Hz (the trade study's estimate)
# Needs the wasm32-unknown-unknown target (`rustup target add wasm32-unknown-unknown`).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${here}"
mkdir -p "${here}/../../build"
build() { # name features
  cargo build --release --target wasm32-unknown-unknown ${2:+--features "$2"}
  cp target/wasm32-unknown-unknown/release/axis_controller.wasm "${here}/../../build/axis-$1.wasm"
}
build trapezoid ""
build shaped shaper62
build mistuned shaper69
ls -l "${here}/../../build"/axis-*.wasm
