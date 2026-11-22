/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
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
    attribute :>> printerMass = structure.mass + drive.mass + hotend.mass + bed.mass + supply.mass + control.mass;
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

  /* The lead candidate is the design that is claimed to satisfy the requirements: the ones the trade study judges it to
     meet and the ones a simulation verifies. SYS-020 (the reference print time) is not claimed: nothing yet shows it. */
  satisfy Requirements::'SYS-001' by candidateCoreXYClosedShaped;
  satisfy Requirements::'SYS-002' by candidateCoreXYClosedShaped;
  satisfy Requirements::'SYS-003' by candidateCoreXYClosedShaped;
  satisfy Requirements::'SYS-004' by candidateCoreXYClosedShaped;
  satisfy Requirements::'SYS-005' by candidateCoreXYClosedShaped;
  satisfy Requirements::'SYS-006' by candidateCoreXYClosedShaped;
  satisfy Requirements::'SYS-007' by candidateCoreXYClosedShaped;
  satisfy Requirements::'SYS-008' by candidateCoreXYClosedShaped;
  satisfy Requirements::'SYS-009' by candidateCoreXYClosedShaped;
  satisfy Requirements::'SYS-010' by candidateCoreXYClosedShaped;
  satisfy Requirements::'SYS-011' by candidateCoreXYClosedShaped;
  satisfy Requirements::'SYS-012' by candidateCoreXYClosedShaped;
  satisfy Requirements::'SYS-013' by candidateCoreXYClosedShaped;
  satisfy Requirements::'SYS-014' by candidateCoreXYClosedShaped;
  satisfy Requirements::'SYS-015' by candidateCoreXYClosedShaped;
  satisfy Requirements::'SYS-016' by candidateCoreXYClosedShaped;
  satisfy Requirements::'SYS-017' by candidateCoreXYClosedShaped;
  satisfy Requirements::'SYS-018' by candidateCoreXYClosedShaped;
  satisfy Requirements::'SYS-019' by candidateCoreXYClosedShaped;

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

  /* Each customer requirement is covered by a derivation: the system requirements derived from it, and the reason that
     set is complete. Every system requirement is derived from at least one customer requirement. */
  package Traceability {
    private import RequirementDerivation::*;
    private import ModelingMetadata::*;
    private import StakeholderNeeds::*;
    private import Requirements::*;

    connection fastPrints : Derivation {
      @Rationale { text = "A bracket has to come off within the hour. That takes a toolhead that goes fast (speed), one that can change speed quickly enough for the short moves of a layer (acceleration), a hotend that melts the plastic at that speed (melt flow), and the total, the print time of the reference part, which is what the team lead experiences."; }
      end :>> Derivation::originalRequirement ::> 'USR-001';
      end #derive derived1 ::> 'SYS-002';
      end #derive derived2 ::> 'SYS-003';
      end #derive derived3 ::> 'SYS-011';
      end #derive derived4 ::> 'SYS-020';
    }

    connection partsThatFit : Derivation {
      @Rationale { text = "A part fits when its dimensions are right. The error budget bounds the static error (motor and belt positioning, thermal growth of the frame, geometry and residual vibration); settling and tracking bound the error while the toolhead moves; and a nozzle temperature that holds keeps the extruded line the width the slicer assumed."; }
      end :>> Derivation::originalRequirement ::> 'USR-002';
      end #derive derived1 ::> 'SYS-004';
      end #derive derived2 ::> 'SYS-007';
      end #derive derived3 ::> 'SYS-008';
      end #derive derived4 ::> 'SYS-012';
    }

    connection cleanSurfaces : Derivation {
      @Rationale { text = "Ghosting is the vibration the toolhead leaves behind a corner. It is limited by the acceleration at which it is allowed to appear, by the resonance the vibration rings at, by its amplitude and by how quickly it dies out."; }
      end :>> Derivation::originalRequirement ::> 'USR-003';
      end #derive derived1 ::> 'SYS-003';
      end #derive derived2 ::> 'SYS-005';
      end #derive derived3 ::> 'SYS-006';
      end #derive derived4 ::> 'SYS-007';
    }

    connection readyQuickly : Derivation {
      @Rationale { text = "The wait before the first layer is the longer of the two heat-ups: the nozzle to its printing temperature and the bed to its."; }
      end :>> Derivation::originalRequirement ::> 'USR-004';
      end #derive derived1 ::> 'SYS-009';
      end #derive derived2 ::> 'SYS-013';
    }

    connection commonMaterials : Derivation {
      @Rationale { text = "PLA, PETG and ABS need a nozzle up to 300 degC and a bed up to 100 degC; the requirements give the limits and how long it may take to reach them."; }
      end :>> Derivation::originalRequirement ::> 'USR-005';
      end #derive derived1 ::> 'SYS-010';
      end #derive derived2 ::> 'SYS-013';
    }

    connection quietEnough : Derivation {
      @Rationale { text = "The noise a neighbour hears is the sound pressure level of the machine at full speed, which is the one number that decides whether it is acceptable in a shared office."; }
      end :>> Derivation::originalRequirement ::> 'USR-006';
      end #derive derived1 ::> 'SYS-016';
    }

    connection safeToLeaveRunning : Derivation {
      @Rationale { text = "Fire is the hazard. A supply that cannot deliver what the heaters and motors ask for overloads and heats, and a heater that does not respond as it should is the fault that starts the fire: the supply is rated for the peak, and a runaway is detected and the heater switched off within the time given."; }
      end :>> Derivation::originalRequirement ::> 'USR-007';
      end #derive derived1 ::> 'SYS-014';
      end #derive derived2 ::> 'SYS-015';
    }

    connection fitsOnADesk : Derivation {
      @Rationale { text = "A desk has an area and a person who lifts the printer onto it has a limit: the footprint and the mass."; }
      end :>> Derivation::originalRequirement ::> 'USR-008';
      end #derive derived1 ::> 'SYS-017';
      end #derive derived2 ::> 'SYS-018';
    }

    connection affordable : Derivation {
      @Rationale { text = "What the team pays is the bill of parts, so the cost requirement is the bill of parts. The team lead asks for a few hundred euros; the limit of 750 EUR is our reading of that, taken from assumption A-MARKET-1 (a prosumer printer for engineering teams), and is to be confirmed with the team lead. The lead candidate is estimated at 587 EUR, 163 EUR inside it."; }
      end :>> Derivation::originalRequirement ::> 'USR-009';
      end #derive derived1 ::> 'SYS-019';
    }

    connection keepsItsCalibration : Derivation {
      @Rationale { text = "The calibration of a shaper is the resonance it was tuned to. A resonance that is high enough has a shaper that is not sensitive to a small drift of it, so a calibration that holds for months does not need to be exact."; }
      end :>> Derivation::originalRequirement ::> 'USR-010';
      end #derive derived1 ::> 'SYS-005';
    }

    connection steadyExtrusion : Derivation {
      @Rationale { text = "Thin, weak lines come from too little melt or from a temperature that sags when the flow rises: the melt flow the hotend sustains, and the stability of the temperature at that flow."; }
      end :>> Derivation::originalRequirement ::> 'USR-011';
      end #derive derived1 ::> 'SYS-011';
      end #derive derived2 ::> 'SYS-012';
    }

    connection fitsMyParts : Derivation {
      @Rationale { text = "Parts up to about 25 cm are fitted by a build volume of 250 mm in each direction."; }
      end :>> Derivation::originalRequirement ::> 'USR-012';
      end #derive derived1 ::> 'SYS-001';
    }
  }
}
