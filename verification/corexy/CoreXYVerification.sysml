/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
 */
package CoreXYVerification {
  private import ISQ::*;
  private import SI::*;
  private import ScalarValues::*;
  private import CoreXYPlant::*;
  private import FdmPrinter::Requirements;

  enum def VerificationMethodKind { test; }
  metadata def VerificationMethod { attribute kind : VerificationMethodKind; }

  part def Controller {
    state logic {
      attribute fieldAngleA : AngularMeasureValue = 0 [rad];
      attribute currentCommandA : ElectricCurrentValue = 0 [A];
      attribute fieldAngleB : AngularMeasureValue = 0 [rad];
      attribute currentCommandB : ElectricCurrentValue = 0 [A];
      attribute settlingTime : Real = 0;        // s
      attribute residualAmplitude : Real = 0;   // m
      attribute trackingError : Real = 0;       // m
      attribute finalX : LengthValue;
      attribute finalY : LengthValue;
      entry;
      then running;
      state running;
    }
  }

  verification diagonalMove {
    doc /* The shaped feed move travels 20 mm in the ratio X:Y = 4:3. The monitor uses Euclidean distance in XY. */
    @CoreXYVerification::VerificationMethod { kind = CoreXYVerification::VerificationMethodKind::test; }
    subject controller : Controller;
    objective {
      verify FdmPrinter::Requirements::'SYS-006';
      verify FdmPrinter::Requirements::'SYS-007';
      verify FdmPrinter::Requirements::'SYS-008';
    }
    action stimulus { accept after 0.3 [s]; }
    assert constraint settlesInTime { controller.logic.settlingTime <= 0.05 }
    assert constraint ringsLittle { controller.logic.residualAmplitude <= 0.00005 }
    assert constraint tracks { controller.logic.trackingError <= 0.0001 }
    assert constraint arrives {
      controller.logic.finalX >= 0.01598 [m] and controller.logic.finalX <= 0.01602 [m]
        and controller.logic.finalY >= 0.01198 [m] and controller.logic.finalY <= 0.01202 [m]
    }
  }
}
