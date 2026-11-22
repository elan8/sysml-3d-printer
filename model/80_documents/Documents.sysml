/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
 *
 * The engineering documents of the printer: the customer requirements, the system requirements, the system design and
 * the verification report. Each document is a view; its nested views are the sections, in order. Tables, values and
 * diagrams are read from the model, so they cannot drift from it. A short text is the `doc` of its section, written in
 * Markdown; a long one is a Markdown file in `prose/`. Two prose files are generated and committed:
 * `prose/sds-trade-study.md` by scripts/trade_study.py and `prose/vvr-results.md` with the plots in `figures/` by
 * scripts/write_verification_report.py.
 */
package PrinterDocuments {
  private import Elan8::Documents::*;
  private import StandardViewDefinitions::*;

  view crs {
    @Document {
      title = "Desktop 3D Printer";
      subtitle = "Customer Requirements Specification";
      organization = "Elan8";
      number = "FDM-CRS-001";
      revision = "A";
      status = "Draft for review";
      template = "template";
    }

    view introduction {
      @Section { title = "Introduction"; }
      view purpose {
        @Section { title = "Purpose"; }
        doc /* This specification records what an engineering team expects from a desktop 3D printer. It states the customer requirements in the stakeholders' terms, before any design decision, and is the baseline against which a built printer would be validated. */
      }
      view scope {
        @Section { title = "Scope"; }
        @Prose { file = "prose/crs-scope.md"; }
      }
      view conventions {
        @Section { title = "Document conventions"; }
        @Prose { file = "prose/conventions.md"; }
      }
      view referenceDocuments {
        @Section { title = "Applicable and reference documents"; }
        @Prose { file = "prose/references.md"; }
      }
    }

    view context {
      @Section { title = "Stakeholders and operating context"; }
      @Prose { file = "prose/crs-context.md"; }
      @Figure { file = "../../docs/system-overview/context.svg"; caption = "The printer's boundary: the engineer, the technician, the team lead, the office neighbour, the filament and the mains power"; }
    }

    view scenarios {
      @Section { title = "Operational scenarios"; }
      @Prose { file = "prose/crs-scenarios.md"; }
    }

    view customerRequirements {
      @Section { title = "Customer requirements"; }
      doc /* Each requirement is a need of a stakeholder, stated in the stakeholder's terms and identified by a stable
           * number. None of them says how the product meets it or how that is measured: the system requirements that make
           * each need measurable are in FDM-SRS-001. */
      @Table { columns = "ID = id, Requirement = name, Text = text"; kind = "requirement"; sort = "id"; }
      expose StakeholderNeeds::*;
    }

    view constraints {
      @Section { title = "Constraints and assumptions"; }
      @Prose { file = "prose/crs-constraints.md"; }
      @Table { columns = "ID = .id, Assumption = .statement, Owner = .owner"; kind = "part"; }
      expose ProjectAssumptions::a_market1;
      expose ProjectAssumptions::a_fdm1;
      expose ProjectAssumptions::a_fdm2;
      expose ProjectAssumptions::a_mech1;
      expose ProjectAssumptions::a_acc1;
      expose ProjectAssumptions::a_safe1;
      expose ProjectAssumptions::a_noise1;
    }

    view validation {
      @Section { title = "Validation and open points"; }
      @Prose { file = "prose/crs-validation.md"; }
    }
  }

  view srs {
    @Document {
      title = "Desktop 3D Printer";
      subtitle = "System Requirements Specification";
      organization = "Elan8";
      number = "FDM-SRS-001";
      revision = "A";
      status = "Draft for review";
      template = "template";
    }

    view introduction {
      @Section { title = "Introduction"; }
      view purpose {
        @Section { title = "Purpose"; }
        doc /* This specification states what the printer shall do and how well, as verifiable requirements on the printer as a whole. It refines the customer requirements of FDM-CRS-001 and is the baseline for the design (FDM-SDS-001) and for verification (FDM-VVR-001). It contains no design. */
      }
      view scope {
        @Section { title = "Scope"; }
        doc /* The system of interest is the printer: its mechanics, electronics and firmware. The requirements apply to the printer as delivered, operating in the conditions of use stated in FDM-CRS-001. Slicers, filament and the workspace are external to the system. */
      }
      view conventions {
        @Section { title = "Document conventions"; }
        @Prose { file = "prose/conventions.md"; }
      }
      view referenceDocuments {
        @Section { title = "Applicable and reference documents"; }
        @Prose { file = "prose/references.md"; }
      }
    }

    view overview {
      @Section { title = "System overview"; }
      @Prose { file = "prose/srs-overview.md"; }
    }

    view requirements {
      @Section { title = "System requirements"; }
      doc /* Each requirement constrains one measurable property of the printer and states its limit, and names the
           * customer requirement it was derived from. The limits are read from the model, where the analyses use the
           * same values. */
      view motion {
        @Section { title = "Motion and accuracy"; }
        @Table { columns = "ID = id, Requirement = name, Text = text, Derived from = derived-from / id"; sort = "id"; }
        expose FdmPrinter::Requirements::'SYS-001';
        expose FdmPrinter::Requirements::'SYS-002';
        expose FdmPrinter::Requirements::'SYS-003';
        expose FdmPrinter::Requirements::'SYS-004';
        expose FdmPrinter::Requirements::'SYS-005';
        expose FdmPrinter::Requirements::'SYS-006';
        expose FdmPrinter::Requirements::'SYS-007';
        expose FdmPrinter::Requirements::'SYS-008';
      }
      view thermal {
        @Section { title = "Heating and extrusion"; }
        @Table { columns = "ID = id, Requirement = name, Text = text, Derived from = derived-from / id"; sort = "id"; }
        expose FdmPrinter::Requirements::'SYS-009';
        expose FdmPrinter::Requirements::'SYS-010';
        expose FdmPrinter::Requirements::'SYS-011';
        expose FdmPrinter::Requirements::'SYS-012';
        expose FdmPrinter::Requirements::'SYS-013';
      }
      view safety {
        @Section { title = "Power and safety"; }
        @Table { columns = "ID = id, Requirement = name, Text = text, Derived from = derived-from / id"; sort = "id"; }
        expose FdmPrinter::Requirements::'SYS-014';
        expose FdmPrinter::Requirements::'SYS-015';
      }
      view environment {
        @Section { title = "Environment and handling"; }
        @Table { columns = "ID = id, Requirement = name, Text = text, Derived from = derived-from / id"; sort = "id"; }
        expose FdmPrinter::Requirements::'SYS-016';
        expose FdmPrinter::Requirements::'SYS-017';
        expose FdmPrinter::Requirements::'SYS-018';
        expose FdmPrinter::Requirements::'SYS-019';
      }
      view printing {
        @Section { title = "Use"; }
        @Table { columns = "ID = id, Requirement = name, Text = text, Derived from = derived-from / id"; sort = "id"; }
        expose FdmPrinter::Requirements::'SYS-020';
      }
    }

    view traceability {
      @Section { title = "Traceability to customer requirements"; }
      doc /* Every customer requirement of FDM-CRS-001 has one derivation in the model. The derivation names all system
           * requirements derived from the customer requirement and records why that set is complete: meeting all of them
           * leaves nothing of the customer requirement unmet. Every system requirement is derived from at least one
           * customer requirement. */
      @Table {
        columns = "Customer requirement = original, Derived system requirements = derived, Why this set is complete = @Rationale.text";
        kind = "connection";
        sort = "original";
      }
      expose FdmPrinter::Traceability::*;
    }

    view verificationNote {
      @Section { title = "Verification"; }
      doc /* The requirements that are verified by simulation, and how, are in the Verification Report, FDM-VVR-001. This
           * specification states what is required; it claims nothing about whether the design meets it. */
    }
  }

  view sds {
    @Document {
      title = "Desktop 3D Printer";
      subtitle = "System Design Specification";
      organization = "Elan8";
      number = "FDM-SDS-001";
      revision = "A";
      status = "Draft for review";
      template = "template";
    }

    view introduction {
      @Section { title = "Introduction"; }
      view purpose {
        @Section { title = "Purpose"; }
        doc /* This specification describes how the printer is designed to meet FDM-SRS-001: its subsystems and their alternatives, how the architecture computes the printer's properties from them, the comparison of the candidate printers, the model of one motion axis, and the decision for the lead candidate. */
      }
      view scope {
        @Section { title = "Scope"; }
        doc /* The design described is the lead candidate of the architecture trade study, with the alternatives it was chosen from. It covers the architecture down to the level of the subsystem designs, and one motion axis in detail. Detailed mechanical drawings, circuit schematics and source code are outside this document. */
      }
      view conventions {
        @Section { title = "Document conventions"; }
        @Prose { file = "prose/conventions.md"; }
      }
      view referenceDocuments {
        @Section { title = "Applicable and reference documents"; }
        @Prose { file = "prose/references.md"; }
      }
    }

    view designOverview {
      @Section { title = "Design overview"; }
      @Prose { file = "prose/sds-overview.md"; }
      view lead : InterconnectionView {
        @Section { title = "The lead candidate"; }
        @Diagram { depth = 1; }
        doc /* The six subsystems of the lead candidate, each with the design it selects. */
        expose FdmPrinter::candidateCoreXYClosedShaped;
      }
    }

    view architecture {
      @Section { title = "Architecture"; }
      @Prose { file = "prose/sds-architecture.md"; }
    }

    view subsystems {
      @Section { title = "Subsystem designs"; }
      doc /* Each subsystem has a contract, the properties it offers the printer, and the designs that were compared. The
           * values are the design properties the architecture reads. */
      view structure {
        @Section { title = "Motion structure"; }
        doc /* The three structures. The moving mass is that of the worst axis, without the hotend. */
        @Table { columns = "Design = name, Moving mass = .movingMass, Stiffness (N/m) = .stiffness, Mass = .mass, Cost (EUR) = .cost, Description = text"; kind = "part def"; }
        expose MotionStructureSystem::CoreXYExtrusionArchitecture;
        expose MotionStructureSystem::CoreXYWideSheetArchitecture;
        expose MotionStructureSystem::BedSlingerArchitecture;
      }
      view drive {
        @Section { title = "Motor drive"; }
        doc /* The three drives. */
        @Table { columns = "Design = name, Force at speed = .forceAtSpeed, Max belt speed = .maxBeltSpeed, Noise (dB(A)) = .noiseAt1m, Cost (EUR) = .cost, Description = text"; kind = "part def"; }
        expose MotorDriveSystem::StepperOpenLoopArchitecture;
        expose MotorDriveSystem::StepperClosedLoopArchitecture;
        expose MotorDriveSystem::ServoBldcArchitecture;
      }
      view hotend {
        @Section { title = "Hotend"; }
        doc /* The three hotends. */
        @Table { columns = "Design = name, Heater power = .heaterPower, Max flow (mm^3/s) = .maxFlow, Mass = .mass, Cost (EUR) = .cost, Description = text"; kind = "part def"; }
        expose HotendSystem::StandardHotendArchitecture;
        expose HotendSystem::AllMetalHotendArchitecture;
        expose HotendSystem::HighFlowHotendArchitecture;
      }
      view bed {
        @Section { title = "Heated bed"; }
        doc /* The two beds. */
        @Table { columns = "Design = name, Heater power = .heaterPower, Cost (EUR) = .cost, Description = text"; kind = "part def"; }
        expose BedSystem::Bed300WArchitecture;
        expose BedSystem::Bed400WArchitecture;
      }
      view supply {
        @Section { title = "Power supply"; }
        doc /* The three supplies. */
        @Table { columns = "Design = name, Rated power = .ratedPower, Mass = .mass, Cost (EUR) = .cost, Description = text"; kind = "part def"; }
        expose PowerSupplySystem::Supply360WArchitecture;
        expose PowerSupplySystem::Supply480WArchitecture;
        expose PowerSupplySystem::Supply600WArchitecture;
      }
      view control {
        @Section { title = "Motion and heater control"; }
        doc /* The three control designs. The ringing factor is the residual vibration over what a trapezoidal move leaves. */
        @Table { columns = "Design = name, Ringing factor = .ringingFactor, Runaway detection = .runawayDetectionTime, Cost (EUR) = .cost, Description = text"; kind = "part def"; }
        expose MotionControlSystem::BasicControlArchitecture;
        expose MotionControlSystem::StandardControlArchitecture;
        expose MotionControlSystem::AdvancedControlArchitecture;
      }
    }

    view candidates {
      @Section { title = "Candidate printers"; }
      doc /* Each candidate selects one design per subsystem. */
      @Table { columns = "Candidate = name, Selection = text"; kind = "part def"; }
      expose FdmPrinter::CoreXYClosedShapedIntegration;
      expose FdmPrinter::CoreXYWideServoShapedIntegration;
      expose FdmPrinter::CoreXYOpenShapedIntegration;
      expose FdmPrinter::CoreXYClosedBasicIntegration;
      expose FdmPrinter::SlingerClosedShapedIntegration;
      expose FdmPrinter::SlingerOpenBasicIntegration;
    }

    view tradeStudy {
      @Section { title = "Architecture trade study"; }
      @Prose { file = "prose/sds-trade-study.md"; }
    }

    view axisModel {
      @Section { title = "One motion axis"; }
      @Prose { file = "prose/sds-axis.md"; }
      @Figure { file = "figures/axis-plant.svg"; caption = "The axis plant: a stepper motor, a pulley, the belt as a spring and the carriage as a mass (AxisPlant::BeltAxis)"; }
    }

    view decision {
      @Section { title = "Decision"; }
      @Prose { file = "prose/sds-decision.md"; }
    }

    view satisfaction {
      @Section { title = "Requirement satisfaction"; }
      doc /* The printer specification satisfies each system requirement; satisfaction is a design claim, not a test result.
           * The verification of the requirements is in FDM-VVR-001. */
      @Table { columns = "ID = id, Requirement = name, Satisfied by = satisfied-by"; kind = "requirement"; sort = "id"; }
      expose FdmPrinter::Requirements::*;
    }

    view openPoints {
      @Section { title = "Open points"; }
      @Prose { file = "prose/sds-open.md"; }
    }
  }

  view vvr {
    @Document {
      title = "Desktop 3D Printer";
      subtitle = "Verification Report";
      organization = "Elan8";
      number = "FDM-VVR-001";
      revision = "A";
      status = "Draft for review";
      template = "template";
    }

    view introduction {
      @Section { title = "Introduction"; }
      view purpose {
        @Section { title = "Purpose"; }
        doc /* This report records how the printer's requirements are verified and what the verification has shown. It is the baseline for deciding which requirements are met by the design and which are still open. */
      }
      view scope {
        @Section { title = "Scope"; }
        doc /* The report covers the verification of the lead candidate's motion axis by simulation, and states which requirements are not yet verified. It is rewritten from the results of scripts/verify_axis.sh. */
      }
      view conventions {
        @Section { title = "Document conventions"; }
        @Prose { file = "prose/conventions.md"; }
      }
      view referenceDocuments {
        @Section { title = "Applicable and reference documents"; }
        @Prose { file = "prose/references.md"; }
      }
    }

    view approach {
      @Section { title = "Approach"; }
      @Prose { file = "prose/vvr-approach.md"; }
    }

    view cases {
      @Section { title = "Verification cases"; }
      doc /* The verification case of the axis. It is run with a controller firmware and a plant selected by a driver file,
           * for each controller of the results below; its objective is the three requirements it verifies. */
      @Table { columns = "Case = name, Verifies = verifies"; kind = "verification case"; }
      expose AxisVerification::*;
    }

    view results {
      @Section { title = "Results"; }
      @Prose { file = "prose/vvr-results.md"; }
      @Figure { file = "figures/axis-open-trapezoid.svg"; caption = "The carriage with an open-loop stepper and a trapezoidal move: it rings for the rest of the run"; }
      @Figure { file = "figures/axis-open-shaped.svg"; caption = "The carriage with an open-loop stepper and a shaper tuned to the axis"; }
      @Figure { file = "figures/axis-servo-shaped.svg"; caption = "The carriage with a brushless servo and a shaper tuned to the axis"; }
    }

    view matrix {
      @Section { title = "Requirements verification matrix"; }
      doc /* Each system requirement, the verification case that verifies it and its method. An empty cell means the
           * requirement is not verified by simulation: it is judged by the architecture's roll-ups in FDM-SDS-001, or it is
           * open. */
      @Table { columns = "ID = id, Requirement = name, Verified by = verified-by, Method = verified-by / @VerificationMethod.kind"; kind = "requirement"; sort = "id"; }
      expose FdmPrinter::Requirements::*;
    }

    view openPoints {
      @Section { title = "Open points"; }
      @Prose { file = "prose/vvr-open.md"; }
    }
  }
}
