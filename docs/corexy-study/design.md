## Design progression

1. **Equivalent axis.** The original model used one stepper, an elastic belt and a carriage. It compared drive
   options and established a closed-loop stepper and a 63.5 Hz input shaper as the baseline for the lead design.
2. **Two-motor stage.** The CoreXY plant resolves the two belt displacements as `X + Y` and `X - Y`. Each motor
   has rotor inertia, electrical dynamics and its own encoder and current control. The symmetric model uses the
   existing 0.67 kg effective mass per axis and two 63 kN/m elastic belt paths.
3. **Directional moves.** The four straight paths use the same 20 mm motion at 300 mm/s and 10 m/s², with the
   63.5 Hz shaper. X drives both motors in the same direction, Y reverses one motor, and the diagonals exchange
   which motor sees the higher speed. The endpoints in millimetres are (16, 12), (20, 0), (0, 20) and (16, −12).
4. **Corner.** Two 20 mm legs meet at a nominal 90° vertex. A quadratic blend starts and ends 0.5 mm from the
   vertex, at 75 mm/s, with continuous velocity and 7.95 m/s² acceleration within the blend. Both runs use this
   nominal path. The shaped run averages the command and a copy delayed by half a period at 63.5 Hz.

## How the runs were judged

Run42 executed the WebAssembly motion-controller firmware with the Modelica plant. The 50 µs traces record the
carriage positions, rotor speeds and both phase currents for each motor. Peak phase current uses the largest
absolute value of either phase. The report recomputes the metrics from each hashed trace.

The authored limits are 100 µm planar tracking error during the move (SYS-008), 50 µm peak error after the move
(SYS-006), entry into a 20 µm settling band within 50 ms (SYS-007), and a final position within 20 µm of the
target on each axis. Tracking is measured against the commanded path including shaping where enabled. A closest
approach to the sharp vertex measures geometric rounding separately.

The results apply to this simulated routing and load. Axis-specific moving mass, varying belt stiffness,
friction and gantry racking still need characterization.
