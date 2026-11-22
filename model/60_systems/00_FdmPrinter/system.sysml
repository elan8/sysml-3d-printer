/*
 * SPDX-FileCopyrightText: 2026 Elan8
 *
 * The printer: its specification (what it promises at its boundary), the measurable system requirements derived
 * from the stakeholder needs, and the traceability between them, then the architecture that rolls the
 * subsystems up and the candidate integrations that are compared.
 */
package FdmPrinter {
  private import ISQ::*;
  private import Quantities::*;
  private import SI::*;
  private import ScalarValues::*;

  /* The properties a requirement can talk about. Values are what a design achieves; the limits they are
     compared to are in Limits. */
  part def FdmPrinterSpecification :> Elan8::SystemsEngineering::SystemSpecification {
    doc /*
     * A desktop fused-filament printer. Everything below is observable at its boundary: moving, heating,
     * printing, failing and standing on a desk.
     */
    // Motion
    attribute buildX : LengthValue;
    attribute buildY : LengthValue;
    attribute buildZ : LengthValue;
    attribute maxSpeed : SpeedValue;
    attribute achievableAcceleration : AccelerationValue;
    attribute positioningError : LengthValue;            // the error budget, root sum of squares (A-ACC-1)
    attribute firstResonance : FrequencyValue;
    attribute ringingAmplitude : LengthValue;            // after a move at the reference acceleration
    attribute settlingTime : DurationValue;
    attribute trackingError : LengthValue;
    // Thermal and extrusion
    attribute hotendHeatUpTime : DurationValue;
    attribute hotendMaxTemperature : ThermodynamicTemperatureValue;
    attribute meltFlow : Real;                           // mm^3/s
    attribute hotendTemperatureError : Real;             // K
    attribute bedHeatUpTime : DurationValue;
    // Power and safety
    attribute peakPower : PowerValue;
    attribute supplyRating : PowerValue;
    attribute runawayDetectionTime : DurationValue;
    // Environment
    attribute noiseAt1m : Real;                          // dB(A)
    attribute footprintWidth : LengthValue;
    attribute footprintDepth : LengthValue;
    attribute printerMass : MassValue;
    attribute cost : Real;                               // euro, bill of parts
    // Use
    attribute referencePrintTime : DurationValue;

    satisfy Requirements::'SYS-001';
    satisfy Requirements::'SYS-002';
    satisfy Requirements::'SYS-003';
    satisfy Requirements::'SYS-004';
    satisfy Requirements::'SYS-005';
    satisfy Requirements::'SYS-006';
    satisfy Requirements::'SYS-007';
    satisfy Requirements::'SYS-008';
    satisfy Requirements::'SYS-009';
    satisfy Requirements::'SYS-010';
    satisfy Requirements::'SYS-011';
    satisfy Requirements::'SYS-012';
    satisfy Requirements::'SYS-013';
    satisfy Requirements::'SYS-014';
    satisfy Requirements::'SYS-015';
    satisfy Requirements::'SYS-016';
    satisfy Requirements::'SYS-017';
    satisfy Requirements::'SYS-018';
    satisfy Requirements::'SYS-019';
    satisfy Requirements::'SYS-020';
  }

  /* The numbers the requirements compare against, in one place. Each cites the stakeholder need and the
     assumption it comes from. */
  package Limits {
    attribute buildRequired : LengthValue = 250 [mm];                   // USR-012, A-MARKET-1
    attribute speedRequired : SpeedValue = 300 [mm / s];                // USR-001
    attribute accelerationRequired : AccelerationValue = 10000 [mm / s ^ 2];
    attribute positioningErrorLimit : LengthValue = 0.1 [mm];           // USR-002, A-ACC-1
    attribute resonanceRequired : FrequencyValue = 50 [Hz];             // A-MECH-1
    attribute ringingLimit : LengthValue = 0.05 [mm];                   // USR-003
    attribute referenceAcceleration : AccelerationValue = 10000 [mm / s ^ 2];
    attribute settlingTimeLimit : DurationValue = 50 [milli * s];       // to within 20 um
    attribute trackingErrorLimit : LengthValue = 0.1 [mm];              // at 300 mm/s
    attribute hotendHeatUpLimit : DurationValue = 60 [s];               // to 215 degC, USR-004
    attribute hotendTemperatureRequired : ThermodynamicTemperatureValue = 573.15 [K];   // 300 degC, A-FDM-1
    attribute meltFlowRequired : Real = 25;                             // mm^3/s, A-FDM-2
    attribute hotendTemperatureErrorLimit : Real = 1.0;                 // K
    attribute bedHeatUpLimit : DurationValue = 240 [s];                 // to 100 degC, A-FDM-1
    attribute runawayDetectionLimit : DurationValue = 10 [s];           // A-SAFE-1
    attribute noiseLimit : Real = 55;                                   // dB(A), A-NOISE-1
    attribute footprintWidthLimit : LengthValue = 460 [mm];
    attribute footprintDepthLimit : LengthValue = 500 [mm];
    attribute printerMassLimit : MassValue = 14 [kg];
    attribute costLimit : Real = 750;                                   // euro, A-MARKET-1
    attribute referencePrintTimeLimit : DurationValue = 60 [min];       // USR-001
  }

  package Requirements {
    doc /* Measurable system requirements. Each constrains a property of the specification and cites the
           stakeholder need it serves; Traceability lists the derivations. */

    requirement def PrinterRequirement {
      subject printer : FdmPrinterSpecification;
    }

    // --- Motion
    requirement <'SYS-001'> 'Build volume' : PrinterRequirement {
      doc /* The build volume is at least 250 mm in each direction. */
      require constraint { printer.buildX >= Limits::buildRequired and printer.buildY >= Limits::buildRequired and printer.buildZ >= Limits::buildRequired }
    }
    requirement <'SYS-002'> 'Print speed' : PrinterRequirement {
      doc /* The toolhead reaches 300 mm/s in any direction. */
      require constraint { printer.maxSpeed >= Limits::speedRequired }
    }
    requirement <'SYS-003'> 'Acceleration' : PrinterRequirement {
      doc /* The toolhead accelerates at 10,000 mm/s^2 without the motors running out of force and without the vibration passing the ringing limit. */
      require constraint { printer.achievableAcceleration >= Limits::accelerationRequired }
    }
    requirement <'SYS-004'> 'Dimensional accuracy' : PrinterRequirement {
      doc /* The error budget (motor and belt positioning, thermal growth of the frame, geometry and residual vibration) is at most 0.1 mm. Rationale: A-ACC-1. */
      require constraint { printer.positioningError <= Limits::positioningErrorLimit }
    }
    requirement <'SYS-005'> 'First resonance' : PrinterRequirement {
      doc /* The first resonance of the worst axis is at least 50 Hz, so that a shaper has little delay to add and is not sensitive to a small shift of the frequency. Rationale: A-MECH-1. */
      require constraint { printer.firstResonance >= Limits::resonanceRequired }
    }
    requirement <'SYS-006'> 'Ringing' : PrinterRequirement {
      doc /* After a move at 10,000 mm/s^2 the residual vibration at the nozzle is at most 0.05 mm. Rationale: A-MECH-1. */
      require constraint { printer.ringingAmplitude <= Limits::ringingLimit }
    }
    requirement <'SYS-007'> 'Settling' : PrinterRequirement {
      doc /* After the end of a move the nozzle is within 20 um of its target in 50 ms. Verified by simulation of the axis and its controller. */
      require constraint { printer.settlingTime <= Limits::settlingTimeLimit }
    }
    requirement <'SYS-008'> 'Tracking' : PrinterRequirement {
      doc /* Along a 300 mm/s move the nozzle stays within 0.1 mm of the commanded position. Verified by simulation. */
      require constraint { printer.trackingError <= Limits::trackingErrorLimit }
    }

    // --- Thermal and extrusion
    requirement <'SYS-009'> 'Hotend heat-up' : PrinterRequirement {
      doc /* The nozzle heats from 25 to 215 degC in 60 s. */
      require constraint { printer.hotendHeatUpTime <= Limits::hotendHeatUpLimit }
    }
    requirement <'SYS-010'> 'Hotend temperature' : PrinterRequirement {
      doc /* The nozzle reaches 300 degC. Rationale: A-FDM-1. */
      require constraint { printer.hotendMaxTemperature >= Limits::hotendTemperatureRequired }
    }
    requirement <'SYS-011'> 'Melt flow' : PrinterRequirement {
      doc /* The hotend melts at least 25 mm^3/s, which is a 0.42 mm line of 0.2 mm layers at 300 mm/s. Rationale: A-FDM-2. */
      require constraint { printer.meltFlow >= Limits::meltFlowRequired }
    }
    requirement <'SYS-012'> 'Nozzle temperature stability' : PrinterRequirement {
      doc /* While printing at full flow the nozzle temperature stays within 1 K of the set value. */
      require constraint { printer.hotendTemperatureError <= Limits::hotendTemperatureErrorLimit }
    }
    requirement <'SYS-013'> 'Bed heat-up' : PrinterRequirement {
      doc /* The bed heats from 25 to 100 degC in 240 s. Rationale: A-FDM-1. */
      require constraint { printer.bedHeatUpTime <= Limits::bedHeatUpLimit }
    }

    // --- Power and safety
    requirement <'SYS-014'> 'Power supply' : PrinterRequirement {
      doc /* The peak power the printer can ask for, with both heaters and all motors at full power, is within the supply's rating. */
      require constraint { printer.peakPower <= printer.supplyRating }
    }
    requirement <'SYS-015'> 'Thermal runaway detection' : PrinterRequirement {
      doc /* A heater that does not respond as it should is detected within 10 s and switched off. Rationale: A-SAFE-1. */
      require constraint { printer.runawayDetectionTime <= Limits::runawayDetectionLimit }
    }

    // --- Environment and handling
    requirement <'SYS-016'> 'Noise' : PrinterRequirement {
      doc /* At most 55 dB(A) at 1 m at full speed. Rationale: A-NOISE-1. */
      require constraint { printer.noiseAt1m <= Limits::noiseLimit }
    }
    requirement <'SYS-017'> 'Footprint' : PrinterRequirement {
      doc /* The printer stands on a desk area of at most 460 mm by 500 mm. */
      require constraint { printer.footprintWidth <= Limits::footprintWidthLimit and printer.footprintDepth <= Limits::footprintDepthLimit }
    }
    requirement <'SYS-018'> 'Mass' : PrinterRequirement {
      doc /* The printer weighs at most 14 kg, so one person can lift it onto a desk. */
      require constraint { printer.printerMass <= Limits::printerMassLimit }
    }
    requirement <'SYS-019'> 'Cost' : PrinterRequirement {
      doc /* The bill of parts is at most 750 EUR. Rationale: A-MARKET-1. */
      require constraint { printer.cost <= Limits::costLimit }
    }
    requirement <'SYS-020'> 'Reference print time' : PrinterRequirement {
      doc /* The 100 mm by 100 mm by 20 mm reference bracket is printed in at most 60 minutes. Verified by simulation of the toolpath with the motion limits of the design. */
      require constraint { printer.referencePrintTime <= Limits::referencePrintTimeLimit }
    }
  }

  /* The figures the analysis starts from. The values are plain numbers in the units of their names. */
  package Reference {
    attribute ambientTemperatureKelvin : Real = 298.15;                  // 25 degC
    attribute hotendTargetRise : Real = 190;                             // K, from 25 to 215 degC
    attribute bedTargetRise : Real = 75;                                 // K, from 25 to 100 degC
    attribute hotendLoss : Real = 4;                                     // W, mean while heating
    attribute frameWarmUp : Real = 10;                                   // K, A-ACC-1
    attribute buildLength : Real = 0.25;                                 // m
    attribute accelerationMps2 : Real = 10;                              // 10,000 mm/s^2
    attribute electronicsOverhead : Real = 0;                            // W, in the control design
  }

  /* The architecture: six subsystems, each described by its own contract. Which design of each is used is
     chosen by an integration below. */
  part def FdmPrinterArchitecture
      :> FdmPrinterSpecification, Elan8::SystemsEngineering::SystemArchitecture {
    doc /*
     * Structure, drive, hotend, bed, power supply and control. The printer's properties are rolled up from them:
     * masses and costs add; the first resonance follows from the moving mass and the stiffness, the ringing from
     * the resonance, the acceleration and the control; the heat-up times from the thermal masses and heater powers.
     */
    part structure : MotionStructureSystem::StructureSpecification;
    part drive : MotorDriveSystem::DriveSpecification;
    part hotend : HotendSystem::HotendSpecification;
    part bed : BedSystem::BedSpecification;
    part supply : PowerSupplySystem::SupplySpecification;
    part control : MotionControlSystem::ControlSpecification;

    attribute :>> buildX = structure.buildX;
    attribute :>> buildY = structure.buildY;
    attribute :>> buildZ = structure.buildZ;
    attribute :>> footprintWidth = structure.footprintWidth;
    attribute :>> footprintDepth = structure.footprintDepth;
    attribute :>> printerMass = structure.mass + drive.mass + hotend.mass + supply.mass;
    attribute :>> cost = structure.cost + drive.cost + hotend.cost + bed.cost + supply.cost + control.cost;
    attribute :>> meltFlow = hotend.maxFlow;
    attribute :>> hotendMaxTemperature = hotend.maxTemperature;
    attribute :>> hotendTemperatureError = control.hotendTemperatureError;
    attribute :>> noiseAt1m = drive.noiseAt1m;
    attribute :>> runawayDetectionTime = control.runawayDetectionTime;
    attribute :>> supplyRating = supply.ratedPower;
    attribute :>> peakPower = hotend.heaterPower + bed.heaterPower + drive.power + control.power;
    // Heat-up: the energy to warm the thermal mass over what the heater delivers beyond its losses.
    attribute :>> hotendHeatUpTime = hotend.thermalMass * Reference::hotendTargetRise
        / (hotend.heaterPower / 1 [W] - Reference::hotendLoss) * 1 [s];
    attribute :>> bedHeatUpTime = bed.thermalMass * Reference::bedTargetRise
        / ((bed.heaterPower - bed.meanLoss) / 1 [W]) * 1 [s];
    // The maximum speed, the acceleration, the resonance, the ringing and the error budget need a square root or a
    // minimum, which Spec42 does not evaluate through an integration; scripts/trade_study.py computes them from
    // the same design values, and the simulation of the axis replaces the estimates.
  }

  /* Candidates. Each selects one design per subsystem by redefining the child usages. */
  part def CoreXYClosedShapedIntegration
      :> FdmPrinterArchitecture, Elan8::SystemsEngineering::SystemIntegration {
    doc /* CoreXY on an extrusion frame, closed-loop steppers, high-flow hotend, 400 W bed, 600 W supply, advanced control. */
    part redefines structure : MotionStructureSystem::CoreXYExtrusionArchitecture;
    part redefines drive : MotorDriveSystem::StepperClosedLoopArchitecture;
    part redefines hotend : HotendSystem::HighFlowHotendArchitecture;
    part redefines bed : BedSystem::Bed400WArchitecture;
    part redefines supply : PowerSupplySystem::Supply600WArchitecture;
    part redefines control : MotionControlSystem::AdvancedControlArchitecture;
  }
  part candidateCoreXYClosedShaped : CoreXYClosedShapedIntegration;

  part def CoreXYWideServoShapedIntegration
      :> FdmPrinterArchitecture, Elan8::SystemsEngineering::SystemIntegration {
    doc /* CoreXY with wide belts on a sheet-steel frame, brushless servos, high-flow hotend, 400 W bed, 600 W supply, advanced control. */
    part redefines structure : MotionStructureSystem::CoreXYWideSheetArchitecture;
    part redefines drive : MotorDriveSystem::ServoBldcArchitecture;
    part redefines hotend : HotendSystem::HighFlowHotendArchitecture;
    part redefines bed : BedSystem::Bed400WArchitecture;
    part redefines supply : PowerSupplySystem::Supply600WArchitecture;
    part redefines control : MotionControlSystem::AdvancedControlArchitecture;
  }
  part candidateCoreXYWideServoShaped : CoreXYWideServoShapedIntegration;

  part def CoreXYOpenShapedIntegration
      :> FdmPrinterArchitecture, Elan8::SystemsEngineering::SystemIntegration {
    doc /* As the first, but open-loop steppers to save cost. */
    part redefines structure : MotionStructureSystem::CoreXYExtrusionArchitecture;
    part redefines drive : MotorDriveSystem::StepperOpenLoopArchitecture;
    part redefines hotend : HotendSystem::HighFlowHotendArchitecture;
    part redefines bed : BedSystem::Bed400WArchitecture;
    part redefines supply : PowerSupplySystem::Supply600WArchitecture;
    part redefines control : MotionControlSystem::AdvancedControlArchitecture;
  }
  part candidateCoreXYOpenShaped : CoreXYOpenShapedIntegration;

  part def CoreXYClosedBasicIntegration
      :> FdmPrinterArchitecture, Elan8::SystemsEngineering::SystemIntegration {
    doc /* CoreXY on an extrusion frame, closed-loop steppers, all-metal hotend, 400 W bed, 480 W supply and a basic 8-bit control board. */
    part redefines structure : MotionStructureSystem::CoreXYExtrusionArchitecture;
    part redefines drive : MotorDriveSystem::StepperClosedLoopArchitecture;
    part redefines hotend : HotendSystem::AllMetalHotendArchitecture;
    part redefines bed : BedSystem::Bed400WArchitecture;
    part redefines supply : PowerSupplySystem::Supply480WArchitecture;
    part redefines control : MotionControlSystem::BasicControlArchitecture;
  }
  part candidateCoreXYClosedBasic : CoreXYClosedBasicIntegration;

  part def SlingerClosedShapedIntegration
      :> FdmPrinterArchitecture, Elan8::SystemsEngineering::SystemIntegration {
    doc /* A bed-slinger with every electronic improvement: closed-loop steppers, high-flow hotend, 400 W bed, 600 W supply and advanced control. */
    part redefines structure : MotionStructureSystem::BedSlingerArchitecture;
    part redefines drive : MotorDriveSystem::StepperClosedLoopArchitecture;
    part redefines hotend : HotendSystem::HighFlowHotendArchitecture;
    part redefines bed : BedSystem::Bed400WArchitecture;
    part redefines supply : PowerSupplySystem::Supply600WArchitecture;
    part redefines control : MotionControlSystem::AdvancedControlArchitecture;
  }
  part candidateSlingerClosedShaped : SlingerClosedShapedIntegration;

  part def SlingerOpenBasicIntegration
      :> FdmPrinterArchitecture, Elan8::SystemsEngineering::SystemIntegration {
    doc /* The budget bed-slinger: open-loop steppers, standard hotend, 300 W bed, 480 W supply and a basic control board. */
    part redefines structure : MotionStructureSystem::BedSlingerArchitecture;
    part redefines drive : MotorDriveSystem::StepperOpenLoopArchitecture;
    part redefines hotend : HotendSystem::StandardHotendArchitecture;
    part redefines bed : BedSystem::Bed300WArchitecture;
    part redefines supply : PowerSupplySystem::Supply480WArchitecture;
    part redefines control : MotionControlSystem::BasicControlArchitecture;
  }
  part candidateSlingerOpenBasic : SlingerOpenBasicIntegration;

  package Views {
    private import Elan8::SystemsEngineering::*;
    view specification : SpecificationView {
      expose FdmPrinter::FdmPrinterSpecification;
      expose FdmPrinter::Requirements::**;
    }
    view architecture : ArchitectureView {
      expose FdmPrinter::FdmPrinterArchitecture;
    }
    view integration : IntegrationView {
      expose FdmPrinter::candidateCoreXYClosedShaped;
    }
  }

  /* Each system requirement derives from the stakeholder needs it serves. */
  package Traceability {
    private import StakeholderNeeds::*;
    private import Requirements::*;

    dependency 'SYS-001 derives from USR-012' from 'SYS-001' to 'USR-012';
    dependency 'SYS-002 derives from USR-001' from 'SYS-002' to 'USR-001';
    dependency 'SYS-003 derives from USR-001' from 'SYS-003' to 'USR-001';
    dependency 'SYS-003 derives from USR-003' from 'SYS-003' to 'USR-003';
    dependency 'SYS-004 derives from USR-002' from 'SYS-004' to 'USR-002';
    dependency 'SYS-005 derives from USR-003' from 'SYS-005' to 'USR-003';
    dependency 'SYS-005 derives from USR-010' from 'SYS-005' to 'USR-010';
    dependency 'SYS-006 derives from USR-003' from 'SYS-006' to 'USR-003';
    dependency 'SYS-007 derives from USR-002' from 'SYS-007' to 'USR-002';
    dependency 'SYS-007 derives from USR-003' from 'SYS-007' to 'USR-003';
    dependency 'SYS-008 derives from USR-002' from 'SYS-008' to 'USR-002';
    dependency 'SYS-009 derives from USR-004' from 'SYS-009' to 'USR-004';
    dependency 'SYS-010 derives from USR-005' from 'SYS-010' to 'USR-005';
    dependency 'SYS-011 derives from USR-011' from 'SYS-011' to 'USR-011';
    dependency 'SYS-011 derives from USR-001' from 'SYS-011' to 'USR-001';
    dependency 'SYS-012 derives from USR-011' from 'SYS-012' to 'USR-011';
    dependency 'SYS-012 derives from USR-002' from 'SYS-012' to 'USR-002';
    dependency 'SYS-013 derives from USR-004' from 'SYS-013' to 'USR-004';
    dependency 'SYS-013 derives from USR-005' from 'SYS-013' to 'USR-005';
    dependency 'SYS-014 derives from USR-007' from 'SYS-014' to 'USR-007';
    dependency 'SYS-015 derives from USR-007' from 'SYS-015' to 'USR-007';
    dependency 'SYS-016 derives from USR-006' from 'SYS-016' to 'USR-006';
    dependency 'SYS-017 derives from USR-008' from 'SYS-017' to 'USR-008';
    dependency 'SYS-018 derives from USR-008' from 'SYS-018' to 'USR-008';
    dependency 'SYS-019 derives from USR-009' from 'SYS-019' to 'USR-009';
    dependency 'SYS-020 derives from USR-001' from 'SYS-020' to 'USR-001';
  }
}
