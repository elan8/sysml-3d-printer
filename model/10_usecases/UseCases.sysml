/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
 *
 * Operational scenarios: what the engineer, the team lead and the technician do with the printer.
 */
package ProjectUseCases {
  private import ProjectContext::*;
  private import FdmPrinter::*;

  use case def PrepareAndStartPrint {
    doc /* The engineer loads the filament, picks the material profile and starts a print from a sliced file. */
    subject printer : FdmPrinterSpecification;
    actor engineer : Engineer;
    objective { doc /* The nozzle and the bed are at temperature and the first layer is down within five minutes of pressing start. */ }
  }

  use case def PrintPart {
    doc /* The printer moves the toolhead and extrudes plastic layer by layer to the shape of the part. */
    subject printer : FdmPrinterSpecification;
    actor engineer : Engineer;
    actor neighbour : OfficeNeighbour;
    objective { doc /* The part is finished quickly, within tolerance and without ripples or blobs, and the neighbour barely notices the machine. */ }
  }

  use case def ChangeMaterial {
    doc /* The engineer switches from one filament to another, for example PLA to ABS, which needs a hotter nozzle and bed. */
    subject printer : FdmPrinterSpecification;
    actor engineer : Engineer;
    objective { doc /* The change takes less than ten minutes, including the heat-up. */ }
  }

  use case def Calibrate {
    doc /* The technician levels the bed, tunes the heater control and measures the resonance of the axes so the firmware can compensate for it. */
    subject printer : FdmPrinterSpecification;
    actor technician : Technician;
    objective { doc /* The printer is calibrated in under thirty minutes and holds the calibration for the next hundred hours. */ }
  }

  use case def HandleFault {
    doc /* Something fails during a print: a thermistor comes loose, a heater cartridge fails, a motor skips steps or a power cable shorts. */
    subject printer : FdmPrinterSpecification;
    actor engineer : Engineer;
    actor neighbour : OfficeNeighbour;
    objective { doc /* The printer notices, switches the heaters off and stops, without a fire and without damage beyond the print. */ }
  }

  use case def MaintainPrinter {
    doc /* The technician retensions the belts, cleans the rails and replaces the nozzle. */
    subject printer : FdmPrinterSpecification;
    actor technician : Technician;
    objective { doc /* Routine maintenance takes under an hour a month. */ }
  }

  use case def ProduceFunctionalPart {
    doc /* One job: prepare, print, and take the part off the bed. */
    subject printer : FdmPrinterSpecification;
    actor engineer : Engineer;
    objective { doc /* A part that fits comes off the printer within the hour, on the same day it was designed. */ }
    include use case prepareAndStartPrint : PrepareAndStartPrint;
    include use case printPart : PrintPart;
  }
}
