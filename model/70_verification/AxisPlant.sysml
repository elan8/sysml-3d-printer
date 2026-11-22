/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
 *
 * The plant of one motion axis, built from the domain library: a stepper motor on two current-regulated bridges (or a
 * brushless servo), a 20-tooth belt pulley, the belt as a spring and the carriage as a mass. The figures are the lead candidate's
 * (MotionStructureSystem::CoreXYExtrusionArchitecture and HotendSystem::HighFlowHotendArchitecture: a 0.55 kg carriage
 * and a 0.12 kg hotend on a 1.26e5 N/m belt path) and a NEMA 17 motor of 0.45 N m at 1.5 A. A CoreXY pair of motors
 * is modelled as one motor on the equivalent axis. tests/modelica/AxisTests.mo checks the same axis in Modelica
 * against references derived without a simulator.
 */
package AxisPlant {
  private import ISQ::*;
  private import SI::*;
  private import ScalarValues::*;
  private import Elan8::Electronics::Actuation::*;
  private import Elan8::Mechanical::Drivetrain::*;
  private import Elan8::Mechanical::Translational::*;

  part def BeltAxis {
    doc /*
     * One axis: the stepper motor turns a 20-tooth, 2 mm pitch pulley (6.3662 mm radius, so 80 microsteps per mm) that drives the carriage
     * through the belt. The belt is a spring between the pulley and the carriage; the motor's own holding stiffness
     * and the rotor's inertia are part of the axis (the Modelica class of the motor has them). The motor's inputs are
     * the commanded field angle and the peak phase current, which a motion controller provides.
     */
    part motor : StepperMotor {
      attribute :>> phaseResistance = 1.6 [ohm];
      attribute :>> phaseInductance = 3.4 [milli * H];
      attribute :>> torqueConstant = 0.3 [N * m / A];
      attribute :>> rotorTeeth = 50;
      attribute :>> detentTorque = 0 [N * m];
      attribute :>> rotorInertia = 5.7e-6 [kg * m * m];
      attribute :>> supplyVoltage = 24 [V];
      attribute :>> chopperGain = 500 [ohm];
    }
    part pulley : RollingWheel {
      attribute :>> radius = 6.3662 [mm];
    }
    part belt : Spring {
      attribute :>> stiffness = 1.26e5 [N / m];
      attribute :>> unstretchedLength = 0 [m];
    }
    part carriage : Mass {
      attribute :>> mass = 0.67 [kg];
      attribute :>> position := 0 [m];
      attribute :>> velocity := 0 [m / s];
    }
    connect motor.mechanicalOutput to pulley.axle;
    connect pulley.contact to belt.sideA;
    connect belt.sideB to carriage.sideA;
  }

  part def ServoAxis {
    doc /*
     * The same axis with a brushless servo motor in place of the stepper: a four-pole-pair permanent-magnet motor of
     * 0.06 N m/A (the library's dq-frame model, driven by the d and q stator voltages) on a 24 V supply. It is much
     * stronger and quicker than the stepper and has no holding stiffness of its own: the position loop gives it that.
     */
    part motor : PermanentMagnetSynchronousMotor {
      attribute :>> statorResistance = 0.5 [ohm];
      attribute :>> statorInductanceD = 0.5 [milli * H];
      attribute :>> statorInductanceQ = 0.5 [milli * H];
      attribute :>> permanentMagnetFlux = 0.01 [Wb];
      attribute :>> polePairs = 4;
      attribute :>> rotorInertia = 8e-6 [kg * m * m];
    }
    part pulley : RollingWheel {
      attribute :>> radius = 6.3662 [mm];
    }
    part belt : Spring {
      attribute :>> stiffness = 1.26e5 [N / m];
      attribute :>> unstretchedLength = 0 [m];
    }
    part carriage : Mass {
      attribute :>> mass = 0.67 [kg];
      attribute :>> position := 0 [m];
      attribute :>> velocity := 0 [m / s];
    }
    connect motor.mechanicalOutput to pulley.axle;
    connect pulley.contact to belt.sideA;
    connect belt.sideB to carriage.sideA;
  }
}
