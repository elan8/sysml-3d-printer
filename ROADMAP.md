<!--
SPDX-FileCopyrightText: 2026 Elan8
SPDX-License-Identifier: MIT
-->

# Roadmap

What comes next, by theme. There are no version numbers or dates: a theme is done when its completion criterion is met.
The order is the priority. Everything here is a plan, not a promise.

The aim is one decision, the lead architecture of [ADR-001](records/ADR-001-lead-architecture.md), that is traceable
from requirement to evidence and can be reproduced by anyone, rather than more subsystems.

## 1. Evidence that can be reproduced

Anyone can re-run the checks, and CI notices when the committed results no longer match the model.

- Run `scripts/verify-all.sh --run42` in CI against the released Run42 and fail the build if a fresh run changes a committed
  result.
- Done when: a pull request that changes the firmware, the plant or the model without regenerating the results fails CI.

## 2. Print a part

Close SYS-020, the reference print time, which is the one system requirement nothing yet verifies. The requirement stays
as it is: the 100 x 100 x 20 mm bracket in at most 60 minutes. Whether that is the right reference part is a stakeholder
question for the team lead, not something to change because a simulation is slow.

1. **Measure first.** Slice the bracket, simulate one layer with the released Run42, and record the wall-clock time per
   simulated second. This one number decides which route follows.
2. **Route A, if the whole print is affordable:** simulate all of it, as a manual or nightly job whose result is committed,
   so there is nothing to extrapolate.
3. **Route B, if it is not:** compute the print time with a fast model of the move planner (acceleration, junction speeds,
   per-segment time), and check that model against the full simulation on a sample of layers, corners and travel moves.
   The report states the sampled error of the model, not just the result.
4. **The toolpath:** a real one. Generate an STL of the bracket from its dimensions with a small script, slice it with an
   open-source slicer's command line, commit the G-code so that nothing needs the slicer to reproduce, and read it into the
   move list of the driver files. A hand-written G-code generator is the fallback if the slicer cannot be used.
5. **Measure** the print time, the tracking error along the path and the heater and flow demand, with the controller
   firmware and input shaping in the loop.

- Done when: SYS-020 has a verification case with a verdict, `satisfy` of SYS-020 is claimed or withdrawn on that evidence,
  and the Verification Report shows it with its method and its limits.
- Limits to state: this simulates motion, timing and heater demand. It does not simulate material deposition, adhesion or
  the strength of the part.

## 3. Does the decision survive uncertainty?

The choice rests on values that are assumed, not measured: belt stiffness, moving mass and the shaper tuning.

- Vary the belt stiffness by 20 percent in both directions, sweep the moving mass and the controller gain, and vary how far the
  shaper is tuned off.
- Compare the lead candidate with the cheaper open-loop one over the same ranges.
- Done when: ADR-001 states how much each assumed value can change before the decision changes, with the nominal values and
  the ranges kept apart.

## 4. Say what each result is

- Label every result in the studies and the Verification Report as assumed, analytical, simulated or measured.
- Done when: no figure in the documents is without its level, and the Verification Report shows it next to the verdict.

## 5. Model consistency

- The roll-ups of mass, cost and power are computed by `scripts/trade_study.py` because Spec42 does not evaluate them
  through an integration ([elan8/spec42#511](https://github.com/elan8/spec42/issues/511)). Done when Spec42 does, and the
  script reads the values from the model instead of repeating the expressions.
- Confirm the cost limit of 750 EUR with the team lead (USR-009), or change it.
- Decide whether ABS in a shared office needs requirements (fume emission, enclosure, an operator warning) or stays out of
  scope, and record the decision in ADR-001.

## 6. The walkthrough

- A short walkthrough in the README or a separate page: requirement, alternatives, choice, simulation, evidence, each linking
  to the model element and the document section.
- Done when: a reader who does not know SysML can follow one requirement from the stakeholder's words to a verdict.

## Later

- A simplified 3D assembly view of the lead candidate, with selectable parts.
- Measured values from a built printer to replace the assumed ones.
