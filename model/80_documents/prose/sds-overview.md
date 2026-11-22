The printer is described as a **specification**, an **architecture** that rolls the properties of its subsystems up, and several **candidate integrations** that each choose one design per subsystem. The system requirements of FDM-SRS-001 constrain the specification; the architecture computes the properties from the subsystem designs; the trade study compares the candidates against the requirements the architecture decides.

The printer has six subsystems, each described by its own contract:

| Subsystem | What it provides | Designs compared |
| --- | --- | --- |
| Motion structure | The frame, linear guides and belts, and the way the toolhead and the bed move: the build volume, the footprint and mass, the moving mass of the worst axis and the stiffness between motor and nozzle | CoreXY on an aluminium extrusion frame; CoreXY with wide belts on a steel sheet frame; bed-slinger |
| Motor drive | The four motors with their drivers: the force at speed, the speed limit, the positioning error and the noise | Open-loop stepper; closed-loop stepper; brushless servo |
| Hotend | Heater block, nozzle and cooling: the temperature, the heat-up time and the melt flow, and a mass that rides on the axes | Standard PTFE-lined; all-metal; high-flow |
| Heated bed | The build plate and its heater | 300 W; 400 W |
| Power supply | The 24 V supply for the heaters, motors and electronics | 360 W; 480 W; 600 W |
| Motion and heater control | The microcontroller, its motion planner and heater control, and the safety monitor | Basic 8-bit; standard 32-bit; advanced 32-bit with input shaping |

Speed meets stiffness at the axis. The moving mass on the belt and the frame is a spring with a resonance, and every acceleration shakes it; the drive, the belt, the frame and the shaper in the control firmware together decide how fast the printer can go before the vibration shows in the part.
