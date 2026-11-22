"""Check the sampled hotend evidence and regenerate the comparison report and chart."""
# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
import csv
import hashlib
import json

import matplotlib
import numpy as np

from _spec42 import REPO_ROOT
from verify_hotend import CASES, OUT, PHASES

matplotlib.use("Agg")
from matplotlib import pyplot as plt  # noqa: E402

REPORT = REPO_ROOT / "docs" / "hotend-study"
AMBIENT_K, TARGET_K, HEAT_CAPACITY, RATING = 298.15, 488.15, 18.0, 80.0
LOSS_CONDUCTANCE = 2 * 4.0 / (TARGET_K - AMBIENT_K)
FAILURE_S, CUTOFF_LIMIT_S, WARMUP_LIMIT_S, SAMPLE_S = 14.0, 10.0, 60.0, 0.25
TEAL, ORANGE, GREY = "#067c88", "#a44618", "#526a79"
TRACE_COLUMNS = {
    "time_s": "t",
    "temperature_k": "hotend.temperature",
    "command_w": "controller.commandedPower",
    "delivered_w": "hotend.deliveredPower",
    "fault_active": "hotend.faultActive",
    "target_reached": "controller.reachedTarget",
    "alarm": "controller.warmupAlarm",
    "heat_permitted": "heatPermit",
    "phase": "supervisorPhase",
}


def load(name):
    evidence_directory = OUT / name
    record, = json.loads((evidence_directory / "verdicts.json").read_text(encoding="utf-8"))
    if (record["case_name"], record["backend"], record["verdict"]) != (CASES[name][1], "sysml-modelica", "pass"):
        raise ValueError(f"{name}: expected a passing coupled supervisor case: {record['detail']}")
    evidence = record["evidence"]
    trace = evidence_directory / "trace" / evidence["trace"]
    digest = hashlib.sha256(trace.read_bytes()).hexdigest()
    if digest != evidence["trace_sha256"]:
        raise ValueError(f"{name}: trace hash differs from the Run42 verdict")
    with trace.open(encoding="utf-8", newline="") as stream:
        reader = csv.DictReader(stream)
        rows = [[float(row[column]) for column in TRACE_COLUMNS.values()] for row in reader]
    values = np.asarray(rows)
    if len(values) != int(evidence["trace_samples"]) or not np.all(np.isfinite(values)):
        raise ValueError(f"{name}: invalid trace samples")
    data = dict(zip(TRACE_COLUMNS, values.T, strict=True))
    duration = WARMUP_LIMIT_S if name == "nominal" else FAILURE_S + CUTOFF_LIMIT_S
    if data["time_s"][0] != 0 or data["time_s"][-1] != duration or not np.allclose(np.diff(data["time_s"]), SAMPLE_S):
        raise ValueError(f"{name}: expected the complete 250 ms sample grid")
    if not np.all(np.isin(data["phase"], np.arange(len(PHASES)))):
        raise ValueError(f"{name}: unknown supervisor phase in trace")
    return data, digest, evidence["run42_executable_sha256"]


def first_time(data, mask, behavior):
    indices = np.flatnonzero(mask)
    if not len(indices):
        raise ValueError(f"Trace does not show {behavior}")
    return float(data["time_s"][indices[0]])


def check_traces(nominal, weak):
    # Check the undisturbed constant-power segment against the closed-form thermal response.
    t = nominal["time_s"]
    early = t <= 10
    expected = AMBIENT_K + RATING / LOSS_CONDUCTANCE * (-np.expm1(-LOSS_CONDUCTANCE * t[early] / HEAT_CAPACITY))
    analytic_error = float(np.max(np.abs(expected - nominal["temperature_k"][early])))
    if analytic_error > 0.005:
        raise ValueError(f"Initial warm-up differs from the analytical reference by {analytic_error:.6g} K")
    reached = first_time(nominal, nominal["temperature_k"] >= TARGET_K, "nominal target temperature")
    if reached > WARMUP_LIMIT_S or np.any(nominal["alarm"] > 0.5):
        raise ValueError("Nominal warm-up missed its deadline or tripped the watchdog")

    fault = first_time(weak, weak["fault_active"] > 0.5, "the injected power loss")
    if not FAILURE_S <= fault <= FAILURE_S + SAMPLE_S:
        raise ValueError("The trace did not observe the configured failure time")
    alarm = first_time(weak, weak["alarm"] > 0.5, "the warm-up alarm")
    off = ((weak["command_w"] == 0) & (weak["delivered_w"] == 0) & (weak["heat_permitted"] == 0)
           & (weak["phase"] == PHASES.index("fault")))
    cutoff = first_time(weak, off, "both heater powers off with the supervisor in fault")
    residual = weak["delivered_w"][(weak["time_s"] >= fault) & (weak["time_s"] < alarm)]
    if not len(residual) or not np.allclose(residual, RATING * 0.05):
        raise ValueError("Expected 5% residual heater power before the watchdog alarm")
    if not fault < alarm <= cutoff or cutoff - FAILURE_S > CUTOFF_LIMIT_S:
        raise ValueError("The supervisor did not remove heater power within the fault deadline")
    if not np.all(off[weak["time_s"] >= cutoff]):
        raise ValueError("Heat permission or power returned after the recorded cutoff")
    after = weak["time_s"] >= cutoff
    cooling = weak["temperature_k"][after]
    passive_cooling = AMBIENT_K + (cooling[0] - AMBIENT_K) * np.exp(
        -LOSS_CONDUCTANCE * (weak["time_s"][after] - cutoff) / HEAT_CAPACITY
    )
    if not np.allclose(cooling, passive_cooling, rtol=0, atol=0.005):
        raise ValueError("The hotend did not follow its passive cooling response after cutoff")
    return reached, analytic_error, alarm, cutoff


def save_chart(nominal, weak, cutoff):
    figure, (temp, power, state) = plt.subplots(3, 1, sharex=True, figsize=(9.1, 6.2), layout="constrained")
    shown_phases = ("idle", "preparing", "fault")
    phase_positions = {PHASES.index(phase): index for index, phase in enumerate(shown_phases)}
    for label, color, data in (("Nominal", TEAL, nominal), ("Weak heater", ORANGE, weak)):
        time = data["time_s"]
        temp.plot(time, data["temperature_k"] - 273.15, color=color, label=label)
        power.step(time, data["delivered_w"], where="post", color=color, label=f"{label} delivered")
        state.step(time, [phase_positions[int(phase)] for phase in data["phase"]], where="pre",
                   color=color, linestyle="-" if label == "Nominal" else "--")
    power.step(weak["time_s"], weak["command_w"], where="post", color=ORANGE, linestyle=":", label="Weak heater command")
    for axis in (temp, power, state):
        axis.axvline(FAILURE_S, color=GREY, alpha=0.7, linestyle=":")
        axis.axvline(cutoff, color=GREY, alpha=0.7, linestyle="--")
        axis.grid(axis="y", alpha=0.2)
        axis.spines[["top", "right"]].set_visible(False)
    temp.axhline(TARGET_K - 273.15, color=GREY, alpha=0.7, linestyle="-.", label="215 °C target")
    temp.set(ylabel="Hotend (°C)", xlim=(0, WARMUP_LIMIT_S))
    power.set(ylabel="Heater power (W)")
    state.set(yticks=range(len(shown_phases)), yticklabels=[phase.title() for phase in shown_phases],
              ylabel="Supervisor", xlabel="Time (s)")
    temp.legend(loc="lower right", frameon=False)
    power.legend(loc="center", frameon=False, fontsize=9)
    path = REPORT / "comparison.svg"
    figure.savefig(path, metadata={"Date": None}, facecolor="white")
    plt.close(figure)
    lines = path.read_text(encoding="utf-8").splitlines()
    path.write_text("\n".join(line.rstrip() for line in lines) + "\n", encoding="utf-8", newline="\n")


def main():
    plt.rcParams["svg.hashsalt"] = "hotend-study"
    loaded = {name: load(name) for name in CASES}
    if len({run[2] for run in loaded.values()}) != 1:
        raise ValueError("The thermal comparison must use the same Run42 executable")
    nominal, weak = (loaded[name][0] for name in CASES)
    reached, analytic_error, alarm, cutoff = check_traces(nominal, weak)
    REPORT.mkdir(parents=True, exist_ok=True)
    with (REPORT / "samples.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream, lineterminator="\n")
        writer.writerow(("case", *TRACE_COLUMNS))
        for name, (data, _, _) in loaded.items():
            for *row, phase in zip(*data.values(), strict=True):
                writer.writerow((name, *(f"{value:.6f}" for value in row), PHASES[int(phase)]))
    save_chart(nominal, weak, cutoff)
    (REPORT / "README.md").write_text(
        f"""<!-- Generated by scripts/report_hotend.py from local Run42 traces. -->

# Hotend warm-up and weak-heater response

The lead hotend is modeled as an 18 J/K thermal mass with an 80 W heater at 25 °C ambient. Linear heat loss
is fitted to the trade study's 4 W mean loss across the warm-up ramp. A sampled thermostat switches heat
around the 215 °C target. Temperature feedback and heater power cross separate typed links.

The weak-heater case reduces heater authority to 5% at 14 s, so an 80 W command delivers 4 W until the
supervisor revokes permission. The watchdog checks for at least a 4 K rise over a 4 s interval when full heat
is requested and the nozzle is more than 5 K below target at both ends of the interval. Its alarm feeds the
existing print supervisor. The injected fault flag is recorded only for timing.

![Nominal and weak-heater traces showing hotend temperature, heater power and supervisor phase](comparison.svg)

The dotted line marks the injected fault at 14 s. The dashed line marks the first sampled power-off state.
The nominal run remains in Preparing while bed readiness is pending. The weak-heater run ends at 24 s.

| Check | Simulated result | Requirement limit |
| --- | ---: | ---: |
| Nominal warm-up to 215 °C | {reached:.2f} s | 60 s (SYS-009) |
| Warm-up alarm after injected power loss | {alarm - FAILURE_S:.2f} s | Included in the 10 s fault response |
| Heat permit removed, command and delivered power both zero | {cutoff - FAILURE_S:.2f} s | 10 s (SYS-015) |

The cutoff result is an upper bound at the 250 ms sample interval for this injected failure. In the first
10 s of nominal warm-up, the Run42 trajectory differs from the closed-form constant-power response by
at most {analytic_error:.2e} K. The figures are simulation results for one lumped hotend without extrusion load.
Hardware shutoff, sensor faults, and the heated bed need separate verification.

## Reproduce

Set `RUN42` to a local development build and `SPEC42_STDLIB_ROOT` and `RUN42_ENGINES` as described in the
[CoreXY setup](../corexy-model.md). From the repository root, run:

```sh
python3 scripts/verify_hotend.py
python3 scripts/report_hotend.py
```

The report uses NumPy and Matplotlib. The local Run42 verdicts and raw traces are in `build/hotend/`.
The [published samples](samples.csv) include both runs with the following SHA-256 checksums.

- Run42 executable: `{loaded['nominal'][2]}`
- Nominal: `{loaded['nominal'][1]}`
- Weak heater: `{loaded['weak-heater'][1]}`
""", encoding="utf-8", newline="\n",
    )


if __name__ == "__main__":
    main()
