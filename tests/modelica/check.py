"""Check the AxisTests results against references derived without a simulator.

    python3 check.py <directory with <Model>.csv>
"""
import csv
import math
import sys
from pathlib import Path

OUT = Path(sys.argv[1])
results = []


def load(name):
    with open(OUT / f"{name}.csv") as f:
        return [{k: float(v) for k, v in row.items()} for row in csv.DictReader(f)]


def check(name, worst, limit, what):
    ok = worst <= limit
    results.append(ok)
    print(f"{'PASS' if ok else 'FAIL'}  {name}: {what}: worst error {worst:.3g} (limit {limit:.3g})")


# The axis of the lead candidate: a 0.67 kg carriage (0.55 kg of carriage and 0.12 kg of hotend) on a belt path of
# 1.26e5 N/m (the figures of the model), a 20-tooth 2 mm pulley (radius 6.3662 mm) and a NEMA 17 stepper.
M, K_BELT, R_PULLEY, X0 = 0.67, 1.26e5, 0.0063662, 2e-4
R_PH, L_PH, KT, NR, J_ROTOR, KC, I_CMD, V_SUPPLY = 1.6, 3.4e-3, 0.3, 50, 5.7e-6, 500.0, 1.5, 24.0


def first_peak_time(rows, column):
    """Time of the first maximum after the start of a decaying oscillation that starts at its maximum: the first time
    the value passes its minimum and comes back to a local maximum."""
    best = None
    for previous, current, following in zip(rows, rows[1:], rows[2:]):
        if current[column] > previous[column] and current[column] >= following[column] and current["time"] > 1e-3:
            best = current["time"]
            break
    return best


# With the pulley held, the carriage on the belt is one mass on one spring, released from rest 0.2 mm out:
# x(t) = x0 cos(sqrt(k/m) t). This is the trade study's first resonance, sqrt(k/m) / 2 pi = 69 Hz.
rows = load("AxisBeltOnly")
omega = math.sqrt(K_BELT / M)
check("AxisBeltOnly", max(abs(r["carriage.s"] - X0 * math.cos(omega * r["time"])) for r in rows), 1e-9, "carriage position [m]")
print(f"      first resonance of the belt alone: {omega / (2 * math.pi):.2f} Hz")

# Holding a fixed field angle the stepper is a torsional spring, torque = KT I sin(-p theta) = -KT I p theta for small
# angles, which at the belt (x = r theta) is a spring of k_m = KT I p / r^2, and the rotor is a mass J / r^2. The axis
# is then two masses and two springs, and its angular frequencies are the roots of
# m1 m2 w^4 - (m2 (k_m + k_b) + m1 k_b) w^2 + k_m k_b = 0.
K_MOTOR = KT * I_CMD * NR / R_PULLEY ** 2
M_ROTOR = J_ROTOR / R_PULLEY ** 2
a = M_ROTOR * M
b = M * (K_MOTOR + K_BELT) + M_ROTOR * K_BELT
c = K_MOTOR * K_BELT
root = math.sqrt(b * b - 4 * a * c)
w_first, w_second = math.sqrt((b - root) / (2 * a)), math.sqrt((b + root) / (2 * a))
print(f"      stepper holding stiffness at the belt: {K_MOTOR:,.0f} N/m ({K_MOTOR / K_BELT:.1f} times the belt), rotor mass {M_ROTOR:.3f} kg")
print(f"      first resonance of the axis held by the stepper: {w_first / (2 * math.pi):.2f} Hz, second {w_second / (2 * math.pi):.1f} Hz")


def axis_reference(t_end, step=2e-6):
    """Classical fourth-order Runge-Kutta of the full axis: the two phase currents, the rotor angle and speed, the
    carriage position and speed. Written here and not taken from a simulator."""
    def f(x):
        i_a, i_b, theta, w, s, v = x
        phi = NR * theta
        ref_a, ref_b = I_CMD, 0.0                                   # the field at angle 0
        v_a = max(-V_SUPPLY, min(V_SUPPLY, R_PH * ref_a + KC * (ref_a - i_a)))
        v_b = max(-V_SUPPLY, min(V_SUPPLY, R_PH * ref_b + KC * (ref_b - i_b)))
        torque = KT * (-i_a * math.sin(phi) + i_b * math.cos(phi))
        stretch = R_PULLEY * theta - s                              # the belt between the pulley and the carriage
        force = K_BELT * stretch
        return [(v_a - R_PH * i_a + KT * w * math.sin(phi)) / L_PH, (v_b - R_PH * i_b - KT * w * math.cos(phi)) / L_PH,
                w, (torque - R_PULLEY * force) / J_ROTOR, v, force / M]

    x, t, out = [0.0, 0.0, 0.0, 0.0, X0, 0.0], 0.0, {}
    while t < t_end - 1e-12:
        k1 = f(x)
        k2 = f([p + step / 2 * q for p, q in zip(x, k1)])
        k3 = f([p + step / 2 * q for p, q in zip(x, k2)])
        k4 = f([p + step * q for p, q in zip(x, k3)])
        x = [p + step / 6 * (q + 2 * r + 2 * s_ + u) for p, q, r, s_, u in zip(x, k1, k2, k3, k4)]
        t += step
        out[round(t, 6)] = list(x)
    return out


rows = load("AxisStepperHold")
ref = axis_reference(0.05)
sampled = [r for r in rows if round(r["time"], 6) in ref and r["time"] > 0]
assert len(sampled) > 1000, "the axis check must compare many samples"
check("AxisStepperHold", max(abs(r["carriage.s"] - ref[round(r["time"], 6)][4]) for r in sampled), 2e-8, "carriage position against the integrated model [m]")
# The first mode dominates: the first time the carriage is back at its maximum is one period of it.
peak = first_peak_time(rows, "carriage.s")
check("AxisStepperHold", abs(peak - 2 * math.pi / w_first) / (2 * math.pi / w_first), 0.01, "period of the first mode, relative")

print(f"{sum(results)}/{len(results)} checks pass")
sys.exit(0 if all(results) else 1)
