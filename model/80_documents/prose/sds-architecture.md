The architecture computes the properties of the printer from its subsystems. Masses and costs add. The peak power is the sum of the heater powers and the motors' and electronics' power. The heat-up times follow from the thermal mass and the heater power. The following follow from the design values by simple physical models (the assumption A-MECH-1 of the Customer Requirements Specification):

- **First resonance** of the worst axis: the square root of the stiffness over the moving mass, divided by 2 pi. The moving mass includes the hotend if it rides on that axis.
- **Ringing**: a step in acceleration of size a leaves a vibration of amplitude a / omega^2 behind; the control firmware removes a part of it (1 for a trapezoidal move, 0.6 for a jerk-limited one, 0.12 for an input shaper).
- **Acceleration**: the least of what the motors allow, what the ringing limit allows and what the tracking limit allows. The belt stretches by m a / k, and the tracking error of a move is about 1.4 times that.
- **Error budget**: the root sum of squares of the positioning error of the drive, the thermal growth of the frame over a 10 K warm-up, the geometry error and the residual vibration.

The model's specification evaluates the sums and the heat-up times itself; the square roots and minimums are evaluated by the trade-study script, from the same design values.
