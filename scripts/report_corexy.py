"""Summarize a local Run42 CoreXY suite and regenerate the publication data and charts."""
# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
import csv
import hashlib
import json

import matplotlib
import numpy as np

from _spec42 import REPO_ROOT
from verify_corexy import OUT, SCENARIOS

matplotlib.use("Agg")
from matplotlib import pyplot as plt  # noqa: E402

REPORT = REPO_ROOT / "docs" / "corexy-study"
START, TRAVEL, SPEED, ACCEL = 0.002, 0.020, 0.300, 10.0
BLEND, JUNCTION, SHAPER = 0.0005, 0.075, 63.5
DARK, TEAL, ORANGE, GREY = "#162b3b", "#067c88", "#af4b12", "#63778a"
TRACK_LIMIT_UM, RESIDUAL_LIMIT_UM, SETTLING_LIMIT_MS, BAND_UM = 100, 50, 50, 20


def leg(time, distance, end_speed):
    """Position and total duration for a rest-to-speed trapezoid."""
    rise, fall = SPEED / ACCEL, (SPEED - end_speed) / ACCEL
    rise_distance = 0.5 * SPEED * rise
    fall_distance = 0.5 * (SPEED + end_speed) * fall
    cruise = (distance - rise_distance - fall_distance) / SPEED
    duration = rise + cruise + fall
    remaining = duration - time
    position = np.select(
        [time <= 0, time < rise, time < rise + cruise, time < duration],
        [0, 0.5 * ACCEL * time**2, rise_distance + SPEED * (time - rise),
         distance - end_speed * remaining - 0.5 * ACCEL * remaining**2],
        default=distance,
    )
    return position, duration


def nominal_path(time, name):
    if not name.startswith("corner"):
        distance, duration = leg(time, TRAVEL, 0)
        return np.outer(distance / TRAVEL, SCENARIOS[name].target), duration
    approach, duration = leg(time, TRAVEL - BLEND, JUNCTION)
    blend_time = 2 * BLEND / JUNCTION
    total = 2 * duration + blend_time
    u = np.clip((time - duration) / blend_time, 0.0, 1.0)
    x = approach + BLEND * (2 * u - u**2)
    back, _ = leg(total - time, TRAVEL - BLEND, JUNCTION)
    y = np.where(time <= duration + blend_time, BLEND * u**2, TRAVEL - back)
    return np.column_stack((x, y)), total


def load(name):
    directory = OUT / name
    records = json.loads((directory / "verdicts.json").read_text(encoding="utf-8"))
    record, = records
    if record["backend"] != "wasm-modelica" or record["verdict"] not in {"pass", "fail"}:
        raise ValueError(f"{name}: Run42 did not reach an engineering verdict: {record['detail']}")
    evidence = record["evidence"]
    trace = directory / "trace" / evidence["trace"]
    digest = hashlib.sha256(trace.read_bytes()).hexdigest()
    if digest != evidence["trace_sha256"]:
        raise ValueError(f"{name}: trace hash differs from the Run42 verdict")
    with trace.open(encoding="utf-8", newline="") as stream:
        reader = csv.reader(stream)
        columns = dict(zip(next(reader), np.asarray(list(reader), dtype=float).T, strict=True))
    time = columns["t"]
    if len(time) != int(evidence["trace_samples"]) or not np.all(np.diff(time) > 0):
        raise ValueError(f"{name}: invalid trace sampling")
    if not all(np.all(np.isfinite(values)) for values in columns.values()):
        raise ValueError(f"{name}: trace contains non-finite values")
    actual = np.column_stack((columns["carriageX.s"], columns["carriageY.s"]))
    reference, duration = nominal_path(time - START, name)
    delay = 0.5 / SHAPER if SCENARIOS[name].shaped else 0.0
    prior, _ = nominal_path(time - START - delay, name)
    command = 0.5 * (reference + prior)
    done = START + duration + delay
    tracking = np.linalg.norm(actual - command, axis=1)
    endpoint = np.linalg.norm(actual - SCENARIOS[name].target, axis=1)
    moving = (time >= START) & (time <= done)
    post = time > done
    if not np.any(moving) or not np.any(post):
        raise ValueError(f"{name}: motion and settling must both be sampled")

    result = {
        "name": name,
        "verdict": record["verdict"],
        "tracking_um": float(np.max(tracking[moving]) * 1e6),
        "residual_um": float(np.max(endpoint[post]) * 1e6),
        "settling_ms": float(np.max(time[post & (endpoint > BAND_UM * 1e-6)] - done, initial=0) * 1e3),
        "endpoint_um": float(endpoint[-1] * 1e6),
        "final_x_mm": float(actual[-1, 0] * 1e3),
        "final_y_mm": float(actual[-1, 1] * 1e3),
        "corner_miss_um": float(np.min(np.linalg.norm(actual - (TRAVEL, 0), axis=1)) * 1e6)
        if name.startswith("corner") else None,
        "trace_sha256": digest,
        "run42_executable_sha256": evidence["run42_executable_sha256"],
    }
    for motor in ("A", "B"):
        result[f"motor_{motor.lower()}_rpm"] = float(np.max(np.abs(columns[f"motor{motor}.rotorSpeed"])) * 30 / np.pi)
        result[f"motor_{motor.lower()}_peak_phase_current_a"] = float(max(
            np.max(np.abs(columns[f"motor{motor}.currentA"])),
            np.max(np.abs(columns[f"motor{motor}.currentB"])),
        ))
    trace_passes = (
        result["tracking_um"] <= TRACK_LIMIT_UM
        and result["residual_um"] <= RESIDUAL_LIMIT_UM
        and result["settling_ms"] <= SETTLING_LIMIT_MS
        and np.all(np.abs(actual[-1] - SCENARIOS[name].target) * 1e6 <= BAND_UM)
    )
    if trace_passes != (record["verdict"] == "pass"):
        raise ValueError(f"{name}: independently sampled checks disagree with the Run42 verdict")
    return result, time, actual, command


def save_figure(figure, name):
    path = REPORT / name
    figure.savefig(path, metadata={"Date": None}, facecolor="white")
    plt.close(figure)
    # Matplotlib writes spaces at the end of wrapped SVG path coordinates.
    lines = path.read_text(encoding="utf-8").splitlines()
    path.write_text("\n".join(line.rstrip() for line in lines) + "\n", encoding="utf-8", newline="\n")


def plot_errors(results):
    figure, axes = plt.subplots(1, 2, figsize=(9.2, 3.1), layout="constrained")
    labels = [SCENARIOS[result["name"]].label for result in results]
    for axis, key, title, limit in zip(
        axes, ("tracking_um", "residual_um"), ("Peak tracking error", "Peak post-move error"),
        (TRACK_LIMIT_UM, RESIDUAL_LIMIT_UM),
        strict=True,
    ):
        values = [result[key] for result in results]
        bars = axis.barh(labels, values, color=[TEAL if value <= limit else ORANGE for value in values])
        axis.axvline(limit, color=GREY, linestyle="--", linewidth=1)
        axis.bar_label(bars, fmt="%.1f", padding=3, fontsize=9)
        axis.set_xlim(0, max(limit, max(values)) * 1.18)
        axis.invert_yaxis()
        axis.set(title=title, xlabel=f"µm · dashed line: {limit} µm limit")
    axes[1].tick_params(labelleft=False, left=False)
    save_figure(figure, "motion-errors.svg")


def plot_corner(cases):
    figure, axis = plt.subplots(figsize=(5.8, 4.0), layout="constrained")
    margin = 0.55
    axis.plot([-margin, 0, 0], [0, 0, margin], color=GREY, linestyle=":", label="Sharp reference")
    with (REPORT / "corner-samples.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream, lineterminator="\n")
        writer.writerow(("run", "time_ms", "measured_x_mm", "measured_y_mm", "command_x_mm", "command_y_mm"))
        for name, color in (("corner-unshaped", ORANGE), ("corner-shaped", TEAL)):
            _, time, actual, command = cases[name]
            relative = actual * 1e3 - (20, 0)
            near = np.flatnonzero((abs(relative[:, 0]) < 0.65) & (abs(relative[:, 1]) < 0.65))
            if not len(near):
                raise ValueError(f"{name}: the measured path never entered the corner plot window")
            samples = slice(near[0], near[-1] + 1)
            x, y = relative[samples].T
            axis.plot(x, y, color=color, linewidth=2, label=SCENARIOS[name].label)
            if name == "corner-unshaped":
                x, y = (command[samples] * 1e3 - (20, 0)).T
                axis.plot(x, y, color=DARK, linestyle="--", linewidth=1, label="Nominal blend")
            for row in np.column_stack((time[samples], actual[samples], command[samples])) * 1e3:
                writer.writerow([name, *(f"{value:.6f}" for value in row)])
    axis.set(xlim=(-margin, 0.12), ylim=(-0.12, margin), aspect="equal",
             xlabel="X relative to corner (mm)", ylabel="Y relative to corner (mm)")
    axis.legend(loc="upper left", frameon=False, fontsize=9)
    axis.grid(alpha=0.2)
    save_figure(figure, "corner-path.svg")


def table(results):
    lines = [
        "| Run | Verdict | Tracking (µm) | Post-move (µm) | Settling (ms) | Endpoint (µm) |",
        "| --- | --- | ---: | ---: | ---: | ---: |",
    ]
    for row in results:
        lines.append(
            f"| {SCENARIOS[row['name']].label} | {row['verdict'].title()} | {row['tracking_um']:.1f} | "
            f"{row['residual_um']:.1f} | {row['settling_ms']:.2f} | {row['endpoint_um']:.1f} |"
        )
    lines.extend((
        "",
        "| Run | A speed (rpm) | B speed (rpm) | A phase peak (A) | B phase peak (A) |",
        "| --- | ---: | ---: | ---: | ---: |",
    ))
    for row in results:
        lines.append(
            f"| {SCENARIOS[row['name']].label} | {row['motor_a_rpm']:.0f} | {row['motor_b_rpm']:.0f} | "
            f"{row['motor_a_peak_phase_current_a']:.2f} | {row['motor_b_peak_phase_current_a']:.2f} |"
        )
    return "\n".join(lines) + "\n"


def main():
    plt.rcParams.update({"text.color": DARK, "axes.labelcolor": DARK, "axes.spines.top": False,
                         "axes.spines.right": False, "svg.hashsalt": "corexy-study"})
    cases = {name: load(name) for name in SCENARIOS}
    results = [case[0] for case in cases.values()]
    if len({result["run42_executable_sha256"] for result in results}) != 1:
        raise ValueError("The six cases must be run with the same Run42 executable")
    with (REPORT / "summary.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=results[0], lineterminator="\n")
        writer.writeheader()
        writer.writerows(results)
    plot_errors(results)
    plot_corner(cases)
    unshaped = cases["corner-unshaped"][0]
    shaped = cases["corner-shaped"][0]
    outcome = {"pass": "passed", "fail": "failed"}
    findings = (
        f"The unshaped corner **{outcome[unshaped['verdict']]}** the verification case. "
        f"The shaped corner **{outcome[shaped['verdict']]}**. "
        f"Peak tracking error was {unshaped['tracking_um']:.1f} µm without shaping and {shaped['tracking_um']:.1f} µm "
        f"with shaping, against a {TRACK_LIMIT_UM} µm limit.\n\n"
        f"The measured path came within {unshaped['corner_miss_um']:.1f} µm of the sharp vertex without shaping "
        f"and within {shaped['corner_miss_um']:.1f} µm with shaping. The nominal quadratic blend passes "
        f"{BLEND * np.sqrt(2) / 4 * 1e6:.1f} µm from the vertex. This describes corner geometry, "
        "while tracking error is measured against each run's own commanded path.\n"
    )
    results_text = table(results) + "\n" + findings
    (REPORT / "results.md").write_text(results_text, encoding="utf-8", newline="\n")
    design = (REPORT / "design.md").read_text(encoding="utf-8")
    readme = (
        "<!-- Generated by scripts/report_corexy.py. Edit design.md for the design narrative. -->\n\n"
        "# CoreXY toolpath design and verification\n\n" + design
        + "\n## Results\n\n" + results_text
        + "\n![Tracking and post-move error by case](motion-errors.svg)\n\n"
        + "![Measured and nominal paths around the corner](corner-path.svg)\n\n"
        + "[Summary data and trace hashes](summary.csv) · [Corner samples](corner-samples.csv) "
        + "· [CoreXY model and setup](../corexy-model.md)\n"
    )
    (REPORT / "README.md").write_text(readme, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
