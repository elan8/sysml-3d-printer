/*
 * SPDX-FileCopyrightText: 2026 Elan8
 *
 * Project context: the printing job the printer is for, who is involved, and the environment it works in. The
 * reference scenario is an engineering team printing functional prototypes on a desktop fused-filament
 * printer: brackets, jigs, enclosures and fit checks, in PLA, PETG and ABS.
 */
package ProjectContext {
  private import ScalarValues::*;

  doc /*
   * A desktop fused-filament (FFF) 3D printer with a heated bed, a heated nozzle and a motion system that moves
   * the toolhead in X and Y. An engineering team uses it for parts that have to fit: speed, dimensional
   * accuracy and clean surfaces all matter, and it has to be safe to leave running.
   *
   * SCOPE. One printer concept and one process (FFF, a 0.4 mm nozzle). This is a showcase model: it is not a
   * certified design, and its figures are working assumptions (see ProjectAssumptions) to be replaced by
   * sourced values.
   */

  part def Engineer {
    doc /* Designs the part, starts the print and uses the result. Not a printer specialist. */
  }

  part def TeamLead {
    doc /* Pays for the printer and for the time it is busy; wants parts the same day. */
  }

  part def Technician {
    doc /* Calibrates, services and repairs the printer. */
  }

  part def OfficeNeighbour {
    doc /* Shares the room with the printer: hears it, smells it and is at risk if it fails. */
  }

  part def Workspace {
    doc /* A desk or bench in an office or lab, 20 to 28 degC, mains power, no dedicated ventilation. */
    attribute ambientTemperatureLow : ScalarValues::Real = 15;    // degC, working range
    attribute ambientTemperatureHigh : ScalarValues::Real = 30;   // degC, working range
  }

  /* The reference print every figure in the model is sized against. */
  part def ReferencePrint {
    doc /*
     * A 100 mm by 100 mm by 20 mm functional bracket, printed with 0.2 mm layers and 0.42 mm lines at up to
     * 300 mm/s, in PETG at 240 degC with the bed at 80 degC. The printed material is about 12 cm^3.
     */
    attribute layerHeightMillimetres : ScalarValues::Real = 0.2;
    attribute lineWidthMillimetres : ScalarValues::Real = 0.42;
    attribute designSpeedMillimetresPerSecond : ScalarValues::Real = 300;
    attribute materialVolumeCubicCentimetres : ScalarValues::Real = 12;
  }

  part def PrintingContext {
    doc /* Who and what surrounds the printer. The printer itself is the system of interest. */
    part engineer : Engineer;
    part teamLead : TeamLead;
    part technician : Technician;
    part neighbour : OfficeNeighbour;
    part workspace : Workspace;
    part referencePrint : ReferencePrint;
  }

  part printingContext : PrintingContext;
}

/* Working assumptions behind the numbers. Each is to be replaced by a sourced value or accepted by the
   stakeholder it concerns. They are referenced from the requirements' rationale. */
package ProjectAssumptions {
  doc /* Open assumptions, by identifier. */

  part def Assumption {
    attribute id : ScalarValues::String;
    attribute statement : ScalarValues::String;
    attribute owner : ScalarValues::String;
  }

  part a_market1 : Assumption {
    attribute :>> id = "A-MARKET-1";
    attribute :>> statement = "A prosumer printer for engineering teams: a bill of parts of at most 750 EUR is acceptable, a build volume of 250 mm in each direction fits the parts, and PLA, PETG and ABS cover the materials.";
    attribute :>> owner = "Team lead";
  }
  part a_fdm1 : Assumption {
    attribute :>> id = "A-FDM-1";
    attribute :>> statement = "PLA prints at 215 degC, PETG at 240 degC and ABS at 260 degC; a nozzle that reaches 300 degC leaves margin. PETG and ABS want a bed at 80 to 100 degC.";
    attribute :>> owner = "Engineer";
  }
  part a_fdm2 : Assumption {
    attribute :>> id = "A-FDM-2";
    attribute :>> statement = "Melting 0.42 mm lines of 0.2 mm layers at 300 mm/s takes a volumetric flow of 25 mm^3/s (0.42 x 0.2 x 300); the hotend must melt that.";
    attribute :>> owner = "Engineer";
  }
  part a_mech1 : Assumption {
    attribute :>> id = "A-MECH-1";
    attribute :>> statement = "The motion axis is well described by one mass on one spring: the moving mass on the belt-and-frame stiffness, so its first resonance is sqrt(k/m) / 2 pi. A step in acceleration of size a leaves a vibration of amplitude a / omega^2 behind.";
    attribute :>> owner = "Technician";
  }
  part a_acc1 : Assumption {
    attribute :>> id = "A-ACC-1";
    attribute :>> statement = "Dimensional accuracy is the root sum of squares of independent errors: the motor and belt positioning, the thermal growth of the frame over a 10 K warm-up, the geometry of the axes (squareness and straightness) and the residual vibration after a move.";
    attribute :>> owner = "Engineer";
  }
  part a_safe1 : Assumption {
    attribute :>> id = "A-SAFE-1";
    attribute :>> statement = "A heater that cannot reach its set temperature, or that exceeds it, is a fire risk. The firmware must notice and switch the heater off within 10 s; an independent hardware cut-out at 320 degC backs it up. No claim of compliance with any standard is made.";
    attribute :>> owner = "Office neighbour";
  }
  part a_noise1 : Assumption {
    attribute :>> id = "A-NOISE-1";
    attribute :>> statement = "A device is acceptable in a shared office when it is at most 55 dB(A) at 1 m.";
    attribute :>> owner = "Office neighbour";
  }
}
