<!--
SPDX-FileCopyrightText: 2026 Elan8
SPDX-License-Identifier: MIT
-->

# Contributing

Thanks for helping improve this SysML v2 showcase of a desktop 3D printer.

## Pull requests

- Keep model semantics clear and reviewable, and prefer small, focused pull requests.
- Run the checks that apply before opening one (see the README for how to set them up):

  ```sh
  python3 scripts/validate_spec42.py                 # the model has no errors or warnings
  python3 -B -m unittest discover -s tests           # the trade study, the generated files, the axis design
  ```

- If you change a design value, a limit or a requirement, regenerate what is derived from it and commit the result:
  `python3 scripts/trade_study.py --write` writes `docs/trade-study.md` and the trade-study tables of the
  System Design Specification, and `python3 scripts/generate_axis_drivers.py` writes the Run42 driver files.
  The tests fail when a generated file is stale.
- Keep the model layout (`00_context` to `80_documents`, one system package per system under `60_systems`) unless a pull
  request motivates a structural change.
- Keep requirement identifiers (`USR-...`, `SYS-...`) stable: traceability, the trade study and the documents refer to them.
- Say where a number comes from. A figure in the model is a working assumption unless it cites a source; add it to
  `ProjectAssumptions` and refer to it from the requirement that depends on it.
- Avoid unrelated formatting churn in model files.

## Simulation and firmware

- The Modelica reference cases in `tests/modelica` compare the plant with answers derived without a simulator; a new plant
  class should come with one.
- The axis controller firmware (`firmware/axis-controller`) is verified by simulation with Run42
  (`scripts/verify_axis.sh`); `scripts/axis_design.py` is an independent integration that the results are checked against.
  A change to the gains or the move has to keep the two in agreement (`tests/test_axis_design.py` checks the gains).

## Reporting issues

Useful issues include a validation failure, a requirement or an assumption that looks wrong (with a source if you have one),
a figure in a document that does not match the model, and a result that does not reproduce.

By contributing you agree that your contribution is licensed under the MIT License of this repository.
