<!--
SPDX-FileCopyrightText: 2026 Elan8
SPDX-License-Identifier: MIT
-->

# Desktop 3D Printer (SysML v2)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![SysML v2](https://img.shields.io/badge/SysML-v2-0f8fa8.svg)](https://www.omg.org/spec/SysML/)
[![Spec42](https://img.shields.io/badge/validated%20with-Spec42-0f8fa8.svg)](https://github.com/elan8/spec42)

![A CoreXY desktop 3D printer printing a bracket (AI-generated concept illustration)](docs/assets/printer-concept.webp)

*Concept illustration, generated with AI. It is not a photograph of a built printer.*

A worked [SysML v2](https://www.omg.org/spec/SysML/) example of a mechatronic product: a desktop fused-filament 3D
printer for an engineering team that prints functional prototypes. It goes from what the team needs, through measurable
requirements and an architecture trade study, to **simulation of a motion axis with the real controller firmware in the
loop**, and ends in four generated engineering documents.

It is a small system with real trade-offs. Speed, accuracy and stiffness meet at the axis: the toolhead's moving mass on
the belts and the frame is a spring with a resonance, every acceleration shakes it, and the drive, the belt, the frame
and the control firmware together decide how fast the printer can go before the vibration shows in the part. If you are
interested in model-based systems engineering with control engineering in it, this is a complete, runnable example.

> **A showcase, not a design to build.** The figures are working assumptions (`ProjectAssumptions` in the model), to be
> replaced by sourced or measured values. Nothing here claims compliance with any regulation or standard, and a heated,
> mains-powered machine can start a fire. See [NOTICE.md](NOTICE.md).

## System context

![System boundary showing the engineer, technician, team lead, office neighbour, filament and mains power](docs/system-overview/context.svg)

See the [system overview](docs/system-overview/README.md) for the lead architecture and its six subsystems.

## What you can learn from it

The analysis produced results that were not obvious from the requirements:

- **A bed-slinger cannot reach the 50 Hz resonance requirement, whatever the electronics.** Its worst axis is the 1.6 kg bed
  and part on one belt: 38 Hz, against 69 Hz for a CoreXY toolhead. It also overruns the footprint and cannot track within
  0.1 mm at the required acceleration.
- **Input shaping is what meets the ringing limit.** Without a shaper the carriage never settles within 20 um after a
  10 m/s^2 move; with one it leaves 6 um, and the shaper is forgiving: tuned 11 percent off it still leaves 10 um.
- **A stepper motor is part of the axis.** Holding its position it is a spring 4.4 times as stiff as the belt, with a rotor
  that adds a fifth of the carriage's mass. That lowers the first resonance from the 69 Hz of the belt and the moving mass
  alone to 62 Hz, which a first estimate misses.
- **The belt, not the drive, limits the acceleration.** In simulation an open-loop stepper, a closed-loop stepper and a
  brushless servo all follow a move without losing steps, even at 120 m/s^2, and all have the same tracking error: the
  belt stretch m a / k times about 1.4. The 0.1 mm tracking requirement caps the acceleration near 14 m/s^2, only 40 percent
  above the 10 m/s^2 required, so the stiffness of the belt path is the number to measure first.
- **A closed-loop stepper damps the axis.** Its position loop's derivative term lets it settle in 40 ms without a shaper,
  where an open-loop stepper never settles; a servo does no better than a closed-loop stepper on this axis, at twice the
  price.

## Engineering documents

Four documents are defined in [`model/80_documents/Documents.sysml`](model/80_documents/Documents.sysml) with the
`Elan8::Documents` vocabulary and rendered as PDF by [Doc42](https://github.com/elan8/doc42-release). Tables, values and
diagrams are read from the model, so they cannot drift from it.

| Document | Number | Answers |
| --- | --- | --- |
| Customer Requirements Specification | FDM-CRS-001 | What does the team need? Stakeholders, scenarios, 12 customer requirements, the assumptions behind them |
| System Requirements Specification | FDM-SRS-001 | What shall the printer do, and how well? 20 measurable requirements, each with the need it derives from, and why that set is complete |
| System Design Specification | FDM-SDS-001 | How is it designed to do it? Six subsystems and their alternatives, the architecture, the trade study of six candidates, the model of one axis, the decision |
| Verification Report | FDM-VVR-001 | What has the simulation shown? Seven controllers on three drives, the acceleration sweep, the requirements verification matrix, the open points |

CI builds the documents on every run and keeps the PDFs as the `documents` artifact of the run. See
[`model/80_documents/README.md`](model/80_documents/README.md) to build them yourself.

## What is in the repository

| Area | Where |
| --- | --- |
| Context, stakeholders, the reference print and the assumptions | `model/00_context` |
| Operational scenarios | `model/10_usecases` |
| Customer requirements in the stakeholders' own words (12) | `model/20_requirements` |
| The printer specification, limits, 20 system requirements, the architecture, six candidate integrations and the derivation of every requirement | `model/60_systems/00_FdmPrinter` |
| Six subsystems (motion structure, motor drive, hotend, bed, power supply, control), each with a contract and two or three designs | `model/60_systems/*System` |
| The plant of one axis and the verification case that runs the firmware on it | `model/70_verification` |
| The four engineering documents: their sources, prose, figures and house template | `model/80_documents` |
| The architecture trade study, generated from the model | `docs/trade-study.md`, `scripts/trade_study.py` |
| The decision record for the lead candidate | `records/ADR-001-lead-architecture.md` |
| The axis plant as Modelica, with reference cases that have exact answers | `tests/modelica`, `docs/axis-model.md` |
| The motion controller firmware (WebAssembly, three drives) and its verification | `firmware/axis-controller`, `verification`, `docs/axis-verification.md` |
| An independent integration of the whole axis, where the controller gains were chosen | `scripts/axis_design.py` |
| Two-motor CoreXY plant and diagonal verification | [CoreXY motion model](docs/corexy-model.md) |
| Directional moves and corner design study with its simulation data | [CoreXY toolpath verification](docs/corexy-study/README.md) |
| Print-job lifecycle, supervisor interfaces and software ownership | [Print-job supervision](docs/print-supervisor.md) |
| Hotend warm-up, watchdog and power-cutoff traces | [Hotend verification](docs/hotend-study/README.md) |

Each system requirement constrains a property of the specification against a number in `Limits`, and every customer
requirement has a derivation (`Traceability`) that names the system requirements derived from it and why they are enough.

## Status

1. **Context, use cases and requirements**: done.
2. **Architecture alternatives**: done for the first pass: six candidates compared, with the lead candidate proposed in
   ADR-001 (a CoreXY on an extrusion frame with closed-loop steppers, a high-flow hotend and a 32-bit board with input shaping).
3. **One axis**: a stepper motor, a belt and a carriage with a resonance, as Modelica classes with exact-answer checks
   ([axis model](docs/axis-model.md)).
4. **Verification of the axis** with Run42, with the motion controller's firmware in the loop
   ([axis verification](docs/axis-verification.md)).
5. **CoreXY motion**: two motor and belt paths model simultaneous X/Y motion ([CoreXY motion model](docs/corexy-model.md)),
   with directional moves and a corner design study ([toolpath verification](docs/corexy-study/README.md)).
6. **Print-job supervision and the hotend**: the job lifecycle and supervisor interfaces
   ([print-job supervision](docs/print-supervisor.md)), and hotend warm-up, watchdog and power cut-off
   ([hotend verification](docs/hotend-study/README.md)).
7. **Documents** generated with Doc42, as above.

## Try it

You need Python 3.10 or later with numpy. The model is validated with [Spec42](https://github.com/elan8/spec42), which the
scripts download at the release pinned in `.spec42-version`.

The axis uses the stepper motor from [Elan8 domain libraries v0.9.0](https://github.com/elan8/sysml-domain-libraries/releases/tag/v0.9.0).
The Python scripts download and verify the SysML library pinned in `config/domain-library.json`. For the Modelica
reference cases, extract `elan8-domain-modelica-0.9.0.zip` from the same release and set `ELAN8_MODELICA` to the directory
that contains `Elan8/`.

```sh
python3 scripts/validate_spec42.py                 # 0 errors, 0 warnings
python3 -B -m unittest discover -s tests           # the trade study, the generated files, the axis design
python3 scripts/trade_study.py                     # the trade study, printed
python3 scripts/axis_design.py                     # the axis controllers, integrated in Python
bash tests/modelica/run.sh                         # the plant against exact answers; needs the GitHub CLI (gh), Linux x86_64
```

What needs more:

- **Verification with the firmware in the loop** (`scripts/verify_axis.sh`) uses [Run42](https://github.com/elan8/run42-release),
  Elan8's simulation tool, and the Rust target `wasm32-unknown-unknown` to build the firmware.
- **Rendering the documents** uses [Doc42](https://github.com/elan8/doc42-release). `doc42 check model` works without
  an account; `doc42 build` needs an Elan8 API token (`ELAN8_TOKEN`, created at [elan8.com](https://elan8.com)).
  The [document build instructions](model/80_documents/README.md#build) show how to load the pinned domain library.

Run42 and Doc42 are Elan8 products. The model, the scripts, the firmware, the plant models and the results in this repository
are MIT-licensed, and everything except the verification run and the PDF rendering can be run with the free tools above.

## How the verification is done

The verification case `AxisVerification::moveTest` is a SysML v2 `verification` with an objective (the requirements it
verifies) and assertions. The firmware (a WebAssembly guest) plays a 20 mm move at 300 mm/s and 10,000 mm/s^2 and drives the
axis plant, whose Modelica behaviour comes from the domain library; a test bench monitor in the firmware, which the
controller never reads, measures the settling, the residual vibration and the tracking error. A driver file selects the
firmware and the plant: seven controllers are run, an open-loop stepper, a closed-loop stepper and a brushless servo, each
with and without an input shaper. The plant parts are checked against references derived without a simulator, and the results
are checked against an independent Python integration to under a micrometre.

## Method

The folder layout follows the [Elan8 MBSE methodology](https://github.com/elan8/mbse-methodology): numbered model areas, one
system package per system under `60_systems`, and the selected root system in `00_FdmPrinter`. It complements
[sysml-robot-vacuum-cleaner](https://github.com/elan8/sysml-robot-vacuum-cleaner), which shows the model-to-documents path
for a product without simulation: this example adds a plant, firmware and verification by simulation.

## Contributing

Contributions are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md). Report
security concerns as described in [SECURITY.md](SECURITY.md). If you use this example, [CITATION.cff](CITATION.cff) has the
reference.

## License

MIT. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
