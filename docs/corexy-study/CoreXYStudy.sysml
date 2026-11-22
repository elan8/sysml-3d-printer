/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
 */
package CoreXYStudy {
  private import Elan8::Documents::*;

  view report {
    @Document {
      title = "CoreXY toolpath design and verification";
      subtitle = "Desktop 3D Printer";
      organization = "Elan8";
      number = "FDM-MOTION-001";
      revision = "A";
      status = "Simulation study";
    }
    view design {
      @Section { title = "Design and verification method"; }
      @Prose { file = "design.md"; }
    }
    view stage {
      @Section { title = "Stage and measurement points"; }
      doc /* The pulley encoders feed each stepper's field angle and current controller. Run42 uses independent
             nozzle-position samples to score tracking, ringing and settling. */
      @Figure { file = "corexy-plant.svg"; caption = "Belt arrows indicate positive travel. The encoders read pulley travel and the test bench reads nozzle position."; }
    }
    view results {
      @Section { title = "Results"; }
      @Prose { file = "results.md"; }
    }
    view motionErrors {
      @Section { title = "Tracking and settling"; }
      @Figure { file = "motion-errors.svg"; caption = "Peak tracking and post-move error against their limits."; }
    }
    view cornerGeometry {
      @Section { title = "Corner geometry"; }
      @Figure { file = "corner-path.svg"; caption = "The measured corner paths and the nominal blend."; }
    }
  }
}
