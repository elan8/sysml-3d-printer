#!/usr/bin/env python3
"""Design and cross-check the axis controllers: the full electromechanical axis integrated in Python.

The axis is the one of `model/70_verification/AxisPlant.sysml`: a drive (an open-loop or closed-loop stepper, or a brushless
servo), a 20-tooth pulley, the belt as a spring and the carriage as a mass. The controllers are the ones of
`firmware/axis-controller`: a trapezoidal move through an optional zero-vibration shaper, quantised to microsteps, and for
the closed-loop drives a PD position loop (the servo over a PI current loop with decoupling) at 20 kHz. The integration is a
fixed-step fourth-order Runge-Kutta written here, independent of Rumoca and Run42: the gains of the firmware were chosen
with it, and its results agree with the Run42 runs of `scripts/verify_axis.sh` to under a micrometre
(`docs/axis-verification.md`).

    python3 scripts/axis_design.py            # the nominal move for every controller, then a sweep of the acceleration

Needs numpy.
"""
import math

import numpy as np

M, KB, R = 0.67, 1.26e5, 0.0063662            # carriage mass, belt stiffness, pulley radius
S, D, V, A = 0.002, 0.020, 0.300, 10.0        # start, distance, speed and acceleration of the move
# Gains of the firmware (firmware/axis-controller/src/lib.rs; tests/test_axis_design.py checks them).
STEPPER_KP, STEPPER_KD, STEPPER_IMAX = 12_000.0, 15.0, 2.0     # A/m, A s/m, A
SERVO_KP, SERVO_KD, SERVO_IMAX = 53_000.0, 32.0, 6.0           # A/m, A s/m, A
# Shaper frequencies: the axis held by the open-loop stepper, under the closed-loop stepper, under the servo, the belt alone.
SHAPER_OPEN, SHAPER_CLOSED, SHAPER_SERVO, SHAPER_BELT = 62.08, 63.5, 61.5, 69.02

def profile(t, accel=A):
    ta = V/accel; da = 0.5*accel*ta*ta; tc = (D-2*da)/V; total = 2*ta+tc
    if t <= 0: return 0.0
    if t < ta: return 0.5*accel*t*t
    if t < ta+tc: return da+V*(t-ta)
    if t < total: u = total-t; return D-0.5*accel*u*u
    return D
def total_time(accel=A):
    ta = V/accel; da = 0.5*accel*ta*ta; return 2*ta+(D-2*da)/V
def command(t, f, accel=A):
    if f: return 0.5*profile(t-S, accel)+0.5*profile(t-S-0.5/f, accel)
    return profile(t-S, accel)
def quant(x): return round(x*80000.0)/80000.0

# ---- stepper, closed loop
def stepper_cl(kp, kd, f, accel=A, imax=STEPPER_IMAX, t_end=0.3, h=5e-6):
    Rph, Lph, Kt, Nr, J, V_SUP, Kc = 1.6, 3.4e-3, 0.3, 50, 5.7e-6, 24.0, 500.0
    x = np.zeros(6)        # iA, iB, theta, w, s, v
    ctrl_dt = 50e-6; n = int(round(t_end/h)); per = int(round(ctrl_dt/h))
    fa, cur = 0.0, 0.0; prev_xp = 0.0; vf = 0.0
    xs=[]; ts=[]
    def deriv(x, fa, cur):
        ia, ib, th, w, s, v = x; phi = Nr*th
        ra, rb = cur*math.cos(fa), cur*math.sin(fa)
        va = max(-V_SUP, min(V_SUP, Rph*ra+Kc*(ra-ia))); vb = max(-V_SUP, min(V_SUP, Rph*rb+Kc*(rb-ib)))
        T = Kt*(-ia*math.sin(phi)+ib*math.cos(phi))
        force = KB*(R*th-s)
        return np.array([(va-Rph*ia+Kt*w*math.sin(phi))/Lph, (vb-Rph*ib-Kt*w*math.cos(phi))/Lph, w, (T-R*force)/J, v, force/M])
    for k in range(n):
        t = k*h
        if k % per == 0:
            xc = quant(command(t, f, accel)); xp = R*x[2]; 
            vp = R*x[3]
            vc = (command(t+ctrl_dt, f, accel)-command(t, f, accel))/ctrl_dt
            u = kp*(xc-xp)+kd*(vc-vp)
            cur = min(abs(u), imax)
            fa = Nr*x[2] + (math.pi/2 if u >= 0 else -math.pi/2)
        k1 = deriv(x, fa, cur); k2 = deriv(x+h/2*k1, fa, cur); k3 = deriv(x+h/2*k2, fa, cur); k4 = deriv(x+h*k3, fa, cur)
        x = x+h/6*(k1+2*k2+2*k3+k4)
        if k % 10 == 0: ts.append((k+1)*h); xs.append(x[4])
    return np.array(ts), np.array(xs)

def metrics(ts, xs, f, accel=A, command_fn=None):
    delay = 0.5/f if f else 0.0
    done = S+total_time(accel)+delay
    m = ts > done
    dev = np.abs(xs[m]-D)
    outside = ts[m][dev > 20e-6]
    settle = (outside.max()-done) if len(outside) else 0.0
    cmd = np.array([command(t, f, accel) for t in ts])
    track = np.max(np.abs(xs-cmd)[(ts >= S) & (ts <= done)])
    return dict(residual=dev.max()*1e6, settle=settle*1e3, tracking=track*1e6, final=(xs[-1]-D)*1e6)

# ---- brushless servo (the library's dq-frame PMSM), position loop over a dq current loop
def servo(kp, kd, f, accel=A, imax=SERVO_IMAX, t_end=0.3, h=5e-6, ccl=5000.0):
    Rs, Ls, lam, P, J, VDC = 0.5, 0.5e-3, 0.01, 4, 8e-6, 24.0
    vmax = VDC/math.sqrt(3)
    kpc, kic = Ls*ccl, Rs*ccl
    x = np.zeros(6)        # id, iq, theta, w, s, v
    ctrl_dt = 50e-6; n = int(round(t_end/h)); per = int(round(ctrl_dt/h))
    vd = vq = 0.0; integ_d = integ_q = 0.0
    xs=[]; ts=[]
    def deriv(x, vd, vq):
        i_d, i_q, th, w, s, v = x; we = P*w
        T = 1.5*P*lam*i_q
        force = KB*(R*th-s)
        return np.array([(vd-Rs*i_d+we*Ls*i_q)/Ls, (vq-Rs*i_q-we*(Ls*i_d+lam))/Ls, w, (T-R*force)/J, v, force/M])
    for k in range(n):
        t = k*h
        if k % per == 0:
            xc = quant(command(t, f, accel)); xp = R*x[2]; vp = R*x[3]
            vc = (command(t+ctrl_dt, f, accel)-command(t, f, accel))/ctrl_dt
            iq_ref = max(-imax, min(imax, kp*(xc-xp)+kd*(vc-vp)))
            we = P*x[3]
            ed, eq = -x[0], iq_ref-x[1]
            vd = kpc*ed+integ_d-we*Ls*x[1]
            vq = kpc*eq+integ_q+we*(Ls*x[0]+lam)
            mag = math.hypot(vd, vq)
            if mag > vmax:                       # saturated: limit the voltage vector and hold the integrators
                vd, vq = vd*vmax/mag, vq*vmax/mag
            else:
                integ_d += kic*ed*ctrl_dt; integ_q += kic*eq*ctrl_dt
        k1 = deriv(x, vd, vq); k2 = deriv(x+h/2*k1, vd, vq); k3 = deriv(x+h/2*k2, vd, vq); k4 = deriv(x+h*k3, vd, vq)
        x = x+h/6*(k1+2*k2+2*k3+k4)
        if k % 10 == 0: ts.append((k+1)*h); xs.append(x[4])
    return np.array(ts), np.array(xs)

# ---- stepper, open loop
def stepper_open(f, accel=A, current=1.5, t_end=0.3, h=5e-6):
    Rph, Lph, Kt, Nr, J, V_SUP, Kc = 1.6, 3.4e-3, 0.3, 50, 5.7e-6, 24.0, 500.0
    x = np.zeros(6); ctrl_dt = 50e-6; n = int(round(t_end/h)); per = int(round(ctrl_dt/h)); fa = 0.0
    xs=[]; ts=[]
    def deriv(x, fa):
        ia, ib, th, w, s, v = x; phi = Nr*th
        ra, rb = current*math.cos(fa), current*math.sin(fa)
        va = max(-V_SUP, min(V_SUP, Rph*ra+Kc*(ra-ia))); vb = max(-V_SUP, min(V_SUP, Rph*rb+Kc*(rb-ib)))
        T = Kt*(-ia*math.sin(phi)+ib*math.cos(phi)); force = KB*(R*th-s)
        return np.array([(va-Rph*ia+Kt*w*math.sin(phi))/Lph, (vb-Rph*ib-Kt*w*math.cos(phi))/Lph, w, (T-R*force)/J, v, force/M])
    for k in range(n):
        t = k*h
        if k % per == 0: fa = round(command(t, f, accel)*80000.0)*(math.pi/32)
        k1 = deriv(x, fa); k2 = deriv(x+h/2*k1, fa); k3 = deriv(x+h/2*k2, fa); k4 = deriv(x+h*k3, fa)
        x = x+h/6*(k1+2*k2+2*k3+k4)
        if k % 10 == 0: ts.append((k+1)*h); xs.append(x[4])
    return np.array(ts), np.array(xs)


def table():
    print("The nominal move: 20 mm at 300 mm/s and %d m/s^2" % A)
    print("%-17s %9s %9s %9s %9s" % ("", "residual", "settling", "tracking", "final"))
    cases = (("open, trapezoid", lambda: (stepper_open(0.0), 0.0)), ("open, shaped", lambda: (stepper_open(SHAPER_OPEN), SHAPER_OPEN)),
             ("open, mistuned", lambda: (stepper_open(SHAPER_BELT), SHAPER_BELT)),
             ("closed, trapezoid", lambda: (stepper_cl(STEPPER_KP, STEPPER_KD, 0.0), 0.0)),
             ("closed, shaped", lambda: (stepper_cl(STEPPER_KP, STEPPER_KD, SHAPER_CLOSED), SHAPER_CLOSED)),
             ("servo, trapezoid", lambda: (servo(SERVO_KP, SERVO_KD, 0.0), 0.0)),
             ("servo, shaped", lambda: (servo(SERVO_KP, SERVO_KD, SHAPER_SERVO), SHAPER_SERVO)))
    for name, run in cases:
        (ts, xs), f = run()
        m = metrics(ts, xs, f)
        print("%-17s %6.1f um %6.1f ms %6.1f um %6.1f um" % (name, m["residual"], m["settle"], m["tracking"], m["final"]))
    print()
    print("Shaped moves at higher acceleration: tracking error against the commanded position (the belt stretches by m a / k)")
    print("%8s %14s %14s %14s %12s" % ("m/s^2", "open stepper", "closed stepper", "servo", "m a / k"))
    for a in (10, 20, 40, 80):
        track = [metrics(*run(), f, a)["tracking"] for run, f in (
            (lambda: stepper_open(SHAPER_OPEN, a), SHAPER_OPEN), (lambda: stepper_cl(STEPPER_KP, STEPPER_KD, SHAPER_CLOSED, a), SHAPER_CLOSED),
            (lambda: servo(SERVO_KP, SERVO_KD, SHAPER_SERVO, a), SHAPER_SERVO))]
        print("%8d %11.0f um %11.0f um %11.0f um %9.0f um" % (a, *track, M * a / KB * 1e6))


if __name__ == "__main__":
    table()
