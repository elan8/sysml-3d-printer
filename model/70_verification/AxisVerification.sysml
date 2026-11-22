/*
 * SPDX-FileCopyrightText: 2026 Elan8
 *
 * Verification of one axis by simulation: the motion controller's firmware plays a 20 mm move at 300 mm/s and
 * 10,000 mm/s^2 on the axis plant (AxisPlant::BeltAxis), and the test bench monitor in the firmware measures how it
 * came out. The three driver files in verification/ run the same plant with a trapezoidal move, with a zero-vibration
 * input shaper tuned to the axis (62 Hz), and with a shaper tuned to the belt alone (69 Hz); a closed-loop stepper and a
 * brushless servo are run the same way, with and without a shaper.
 */
package AxisVerification {
  private import ScalarValues::*;
  private import ISQ::*;
  private import SI::*;

  enum def VerificationMethodKind { test; }
  metadata def VerificationMethod { attribute kind : VerificationMethodKind; }

  /* What the controller drives and what the test bench measures. The firmware supplies the field angle and the current
     of a stepper, or the stator voltages of a servo, and the three measures; the plant supplies the final position. */
  part def AxisController {
    state logic {
      attribute fieldAngle : AngularMeasureValue = 0 [rad];
      attribute currentCommand : ElectricCurrentValue = 0 [A];
      attribute voltageD : ElectricPotentialValue = 0 [V];      // the servo's stator voltages in the rotor frame
      attribute voltageQ : ElectricPotentialValue = 0 [V];
      attribute settlingTime : Real = 0;           // s, from the end of the commanded motion to the last time outside 20 um
      attribute residualAmplitude : Real = 0;      // m, the largest deviation from the target after the commanded motion
      attribute trackingError : Real = 0;          // m, the largest distance from the commanded position during the move
      attribute finalPosition : LengthValue = 0.02 [m];   // the target, until the plant supplies the measured position
      entry;
      then running;
      state running;
    }
  }

  verification moveTest {
    doc /* Run with one of the driver files in verification/: each selects a controller. */
    @VerificationMethod { kind = VerificationMethodKind::test; }
    subject controller : AxisController;
    objective {
      verify FdmPrinter::Requirements::'SYS-006';
      verify FdmPrinter::Requirements::'SYS-007';
      verify FdmPrinter::Requirements::'SYS-008';
    }
    action stimulus { accept after 0.3 [s]; }
    // SYS-007: within 20 um of the target within 50 ms of the end of the commanded motion.
    assert constraint settlesInTime { controller.logic.settlingTime <= 0.05 }
    // SYS-006: a residual vibration of at most 0.05 mm.
    assert constraint ringsLittle { controller.logic.residualAmplitude <= 0.00005 }
    // SYS-008: within 0.1 mm of the commanded position along the move.
    assert constraint tracks { controller.logic.trackingError <= 0.0001 }
    // The move ends where it was told to: within 20 um of 20 mm.
    assert constraint arrives { controller.logic.finalPosition > 0.01998 [m] and controller.logic.finalPosition < 0.02002 [m] }
  }
}
