/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
 */
package CoreXYPlant {
  private import ISQ::*;
  private import SI::*;
  private import Elan8::Electronics::Actuation::*;
  private import Elan8::Mechanical::Drivetrain::*;
  private import Elan8::Mechanical::Interconnection::*;
  private import Elan8::Mechanical::Translational::*;

  part def CoreXYTransmission {
    doc /* The belt displacements are x + y and x - y. The matching force transform conserves power. */
    @Elan8::PhysicalModeling::ModelicaModel {
      className = "CoreXYTransmission";
      resourceUri = "CoreXYTransmission.mo";
    }
    port beltA : TranslationalMechanicalPort;
    port beltB : TranslationalMechanicalPort;
    port carriageX : TranslationalMechanicalPort;
    port carriageY : TranslationalMechanicalPort;
  }

  part def StepperDrive :> StepperMotor {
    doc /* Same motor and supply assumptions as the equivalent-axis model. */
    attribute :>> phaseResistance = 1.6 [ohm];
    attribute :>> phaseInductance = 3.4 [milli * H];
    attribute :>> torqueConstant = 0.3 [N * m / A];
    attribute :>> rotorTeeth = 50;
    attribute :>> detentTorque = 0 [N * m];
    attribute :>> rotorInertia = 5.7e-6 [kg * m * m];
    attribute :>> supplyVoltage = 24 [V];
    attribute :>> chopperGain = 500 [ohm];
  }

  part def BeltSpan :> Spring {
    doc /* Two equal spans reproduce the assumed 126 kN/m Cartesian stiffness with the motor shafts held. */
    attribute :>> stiffness = 6.3e4 [N / m];
    attribute :>> unstretchedLength = 0 [m];
  }

  part def AxisMass :> Mass {
    doc /* The 0.67 kg worst-axis estimate is used for each direction until the gantry mass is characterized. */
    attribute :>> mass = 0.67 [kg];
    attribute :>> position := 0 [m];
    attribute :>> velocity := 0 [m / s];
  }

  part def XYStage {
    doc /* Verification plant for the lead CoreXY architecture, with the bed fixed in Z. */
    part motorA : StepperDrive;
    part motorB : StepperDrive;
    part pulleyA : RollingWheel { attribute :>> radius = 6.3662 [mm]; }
    part pulleyB : RollingWheel { attribute :>> radius = 6.3662 [mm]; }
    part beltA : BeltSpan;
    part beltB : BeltSpan;
    part transmission : CoreXYTransmission;
    part carriageX : AxisMass;
    part carriageY : AxisMass;
    connect motorA.mechanicalOutput to pulleyA.axle;
    connect motorB.mechanicalOutput to pulleyB.axle;
    connect pulleyA.contact to beltA.sideA;
    connect pulleyB.contact to beltB.sideA;
    connect beltA.sideB to transmission.beltA;
    connect beltB.sideB to transmission.beltB;
    connect transmission.carriageX to carriageX.sideA;
    connect transmission.carriageY to carriageY.sideA;
  }
}
