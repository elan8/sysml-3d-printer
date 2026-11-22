The axis verification case, `AxisVerification::moveTest`, was run with Run42 (development build) for seven controllers: an open-loop stepper, a closed-loop stepper and a brushless servo, each without an input shaper and with one tuned to its own axis, and the open-loop stepper also with a shaper tuned to the belt alone. The move is 20 mm at 300 mm/s and 10,000 mm/s^2. This section is written by `scripts/write_verification_report.py` from the runs of `scripts/verify_axis.sh`.

The case asserts four things: the carriage is within 20 um of its target within 50 ms of the end of the commanded motion (SYS-007); its residual vibration is at most 0.05 mm (SYS-006); it stays within 0.1 mm of the commanded position along the move (SYS-008); and it ends within 20 um of 20 mm.

| Controller | Residual vibration | Settling | Tracking error | Final error | Verdict |
| --- | --- | --- | --- | --- | --- |
| Open-loop stepper, trapezoid | 47.6 um | never within 20 um | 149 um | -43 um | **fail**: arrival, settling (SYS-007), tracking (SYS-008) |
| Open-loop stepper, shaper 62.08 Hz (the axis) | 6.4 um | 0 ms | 80 um | -6 um | passes |
| Open-loop stepper, shaper 69.02 Hz (the belt alone) | 10.1 um | 0 ms | 91 um | -8 um | passes |
| Closed-loop stepper, trapezoid | 40.6 um | 40 ms | 127 um | 0 um | **fail**: tracking (SYS-008) |
| Closed-loop stepper, shaper 63.5 Hz | 1.2 um | 0 ms | 71 um | -0 um | passes |
| Servo, trapezoid | 36.9 um | 97 ms | 137 um | -9 um | **fail**: settling (SYS-007), tracking (SYS-008) |
| Servo, shaper 61.5 Hz | 2.4 um | 0 ms | 72 um | -0 um | passes |

**Reading the results.** Without a shaper no drive meets the tracking limit, and only the closed-loop stepper settles in time, because the derivative term of its position loop damps the 63 Hz mode; the open-loop stepper has no damping to speak of and never settles. With a shaper every drive passes, with 1 to 6 um of residual vibration, which is what the microstep quantisation (12.5 um steps at 20 kHz) leaves. The shaper is forgiving: tuned 11 percent off, to the belt alone, it still leaves 10 um.

**Cross-check.** An independent integration of the whole axis in Python (`scripts/axis_design.py`, a fixed-step Runge-Kutta where the gains were chosen) reproduces these numbers to under a micrometre.

**The belt limits the acceleration.** The same design script sweeps the acceleration of a shaped move (tracking error against the commanded position):

| Acceleration | Open-loop stepper | Closed-loop stepper | Servo | Belt stretch m a / k |
| --- | --- | --- | --- | --- |
| 10 m/s^2 | 80 um | 72 um | 73 um | 53 um |
| 20 m/s^2 | 146 um | 143 um | 144 um | 106 um |
| 40 m/s^2 | 278 um | 253 um | 281 um | 213 um |

No drive loses the move, even at 120 m/s^2. The tracking error is the stretch of the belt, m a / k, times about 1.4, the same for every drive, so the 0.1 mm limit of SYS-008 is reached at about 14 m/s^2: 40 percent above the 10 m/s^2 of SYS-003. The stiffness of the belt path is the number that decides how fast this printer can go.

Plots of the carriage position over the run, as recorded by Run42, follow for three of the controllers.
