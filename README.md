# Desktop 3D printer (SysML v2)

A desktop fused-filament printer for an engineering team that prints functional prototypes: brackets, jigs and
fit checks, in PLA, PETG and ABS. It is a worked example of a model-based systems engineering project that
carries the engineering from the stakeholders' needs to **verification by simulation of the real firmware**, and
ends in generated documents. A small system with real trade-offs between accuracy, stiffness, speed and cost, and
a lot of control engineering: motion planning with input shaping, heater control and fault monitoring.

> **Status: a showcase, not a certified design.** The figures are working assumptions (`ProjectAssumptions`)
> to be replaced by sourced values. Nothing here claims compliance with any regulation or standard.

## The reference scenario

A 100 mm by 100 mm by 20 mm functional bracket, printed with 0.2 mm layers and 0.42 mm lines at up to 300 mm/s
in PETG at 240 degC with the bed at 80 degC. It has to be done within the hour, to a tenth of a millimetre,
without ripples behind the corners, in a shared office.

Speed meets stiffness at the axis: the toolhead's moving mass on the belts and the frame is a spring with a
resonance, and every acceleration shakes it. The controller's input shaper, the motors, the belts and the frame
decide how fast the printer can go before the vibration shows in the part.

## What is in the model

| Area | Where |
| --- | --- |
| Context, stakeholders, reference print and assumptions | `model/00_context` |
| Operational scenarios (use cases) | `model/10_usecases` |
| Stakeholder requirements, in their own words (12) | `model/20_requirements` |
| The printer's specification, limits and 20 measurable system requirements, with derivations | `model/60_systems/00_FdmPrinter` |
| Six subsystems (motion structure, motor drive, hotend, bed, power supply, control), each with a contract and two or three designs | `model/60_systems/*System` |
| The architecture, which rolls their properties up, and six candidate integrations | `00_FdmPrinter/system.sysml` |
| Architecture trade study, generated from the model | `docs/trade-study.md`, `scripts/trade_study.py` |
| Decision record for the lead candidate | `records/ADR-001-lead-architecture.md` |

Each system requirement constrains a property of the specification against a number in `Limits`, and
`Traceability` links it to the stakeholder needs it serves.

## Where it is going

1. **Context, use cases and requirements**: done.
2. **Architecture alternatives**: done for the first pass. Six candidates are compared against the 17
   requirements the architecture decides. The lead candidate (proposed in ADR-001) is a CoreXY on an extrusion
   frame with closed-loop steppers, a high-flow hotend and a 32-bit board with input shaping. A bed-slinger cannot
   reach the resonance whatever the electronics, and without the shaper the CoreXY just misses the ringing limit.
3. **One axis**: a motor, a belt and a carriage with a resonance, as Modelica classes with exact-answer checks.
4. **Verification** with Run42: settling, tracking and ringing of an axis with the motion controller's firmware in
   the loop, with and without input shaping; then the heater control and the runaway monitor.
5. **Documents** generated with Doc42, with the verdicts and plots in them.

## The trade study

```bash
python3 scripts/trade_study.py --write
python3 -B -m unittest discover -s tests
```

Every design value, limit and choice of design is read from the model with `spec42 model-export`. The roll-ups
(mass, cost, heat-up times, first resonance, ringing, acceleration, error budget) repeat the expressions in
`FdmPrinterArchitecture` where Spec42 can evaluate them, and compute the rest (square roots, minimums) from the
same design values, because Spec42 does not evaluate expressions through an integration; the tests check the
outcomes the analysis is expected to give.

## Validate

```bash
python3 scripts/validate_spec42.py
```

The Spec42 release pinned in `.spec42-version` bundles an older domain library, so this project uses the
release named in `config/domain-library.json`: the script downloads its KPAR, checks it against the checksum the
release publishes, and passes it to Spec42 as the managed domain library. It runs `spec42 check` and fails on any
error or warning in this model. Spec42's bundled domain-completeness diagnostics are filtered out unless you pass
`--include-domain-diagnostics`.

## Method

The folder layout follows the [Elan8 MBSE methodology](https://github.com/elan8/mbse-methodology): numbered
model areas, one system package per system under `60_systems`, and the selected root system in
`00_FdmPrinter`. This project complements [sysml-robot-vacuum-cleaner](https://github.com/elan8/sysml-robot-vacuum-cleaner),
which shows the model-to-documents path: this one adds executable verification.

Copyright Elan8. A licence will be chosen before the repository is published.
