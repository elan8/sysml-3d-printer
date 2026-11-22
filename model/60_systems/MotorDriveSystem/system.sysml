/*
 * SPDX-FileCopyrightText: 2026 Elan8
 *
 * The motor drive: the four motors, their drivers and sensing. Three designs are compared: open-loop stepper
 * motors, stepper motors with an encoder and closed-loop current control, and brushless servo motors. Force
 * at speed, positioning error and noise are what separate them.
 */
package MotorDriveSystem {
  private import ISQ::*;
  private import SI::*;
  private import ScalarValues::*;

  part def DriveSpecification :> Elan8::SystemsEngineering::SystemSpecification {
    doc /* What the drive offers: the force at the belt at speed, the speed it can reach, how accurately it positions and how loud it is. */
    attribute mass : MassValue;                       // four motors
    attribute forceAtSpeed : ForceValue;              // per motor, at the belt, at 300 mm/s
    attribute maxBeltSpeed : SpeedValue;
    attribute stepsPerMm : Real;                      // of belt travel
    attribute positioningError : LengthValue;         // microstep nonlinearity, backlash and lost-step margin, at the nozzle
    attribute noiseAt1m : Real;                       // dB(A), at full speed
    attribute power : PowerValue;                     // peak, all four motors
    attribute cost : Real;                            // euro, motors and drivers
  }

  part def StepperOpenLoopArchitecture
      :> DriveSpecification, Elan8::SystemsEngineering::SystemArchitecture {
    doc /* 1.8 degree NEMA 17 steppers with 24 V silent drivers and no feedback. Cheap, but the force falls off with speed, steps can be lost and the motors are audible at speed. */
    attribute :>> mass = 1.4 [kg];
    attribute :>> forceAtSpeed = 28 [N];
    attribute :>> maxBeltSpeed = 450 [mm / s];
    attribute :>> stepsPerMm = 80;
    attribute :>> positioningError = 30 [micro * m];
    attribute :>> noiseAt1m = 56;
    attribute :>> power = 48 [W];
    attribute :>> cost = 70;
  }

  part def StepperClosedLoopArchitecture
      :> DriveSpecification, Elan8::SystemsEngineering::SystemArchitecture {
    doc /* NEMA 17 steppers with a magnetic encoder and closed-loop current control: more force at speed, no lost steps and quieter. */
    attribute :>> mass = 1.9 [kg];
    attribute :>> forceAtSpeed = 36 [N];
    attribute :>> maxBeltSpeed = 800 [mm / s];
    attribute :>> stepsPerMm = 80;
    attribute :>> positioningError = 12 [micro * m];
    attribute :>> noiseAt1m = 52;
    attribute :>> power = 60 [W];
    attribute :>> cost = 150;
  }

  part def ServoBldcArchitecture
      :> DriveSpecification, Elan8::SystemsEngineering::SystemArchitecture {
    doc /* Small brushless servo motors with a high-resolution encoder and field-oriented control. The most force, the highest speed, the least error and the quietest, at about twice the price. */
    attribute :>> mass = 2.4 [kg];
    attribute :>> forceAtSpeed = 55 [N];
    attribute :>> maxBeltSpeed = 1500 [mm / s];
    attribute :>> stepsPerMm = 80;
    attribute :>> positioningError = 6 [micro * m];
    attribute :>> noiseAt1m = 47;
    attribute :>> power = 120 [W];
    attribute :>> cost = 340;
  }
}
