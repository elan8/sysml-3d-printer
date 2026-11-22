Of the 20 system requirements, three are verified by the simulation recorded here: SYS-006 (ringing), SYS-007 (settling) and SYS-008 (tracking), for one axis and one move. The others are judged by the architecture's roll-ups in the System Design Specification, or are open:

- **SYS-020 (reference print time)** needs a simulation of the toolpath with the motion limits of the design.
- **SYS-003 (acceleration)** is estimated; the sweep above shows that the tracking limit, not the motors, decides it, and that the estimate of 13 m/s^2 is consistent with the simulated 14 m/s^2 for one axis.
- **SYS-012 (nozzle temperature stability), SYS-009 and SYS-013 (heat-up) and SYS-015 (runaway detection)** need a thermal model and the heater control firmware.
- A measurement of the belt stiffness would turn the acceleration margin from an estimate into a result.
