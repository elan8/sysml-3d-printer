/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
 */
package SystemOverview {
  private import Elan8::Documents::*;

  view report {
    @Document {
      title = "System context and architecture";
      subtitle = "Desktop 3D Printer";
      organization = "Elan8";
      number = "FDM-OVERVIEW-001";
      revision = "A";
      status = "Concept design";
    }
    view context {
      @Section { title = "System context"; }
      doc /* The printer processes a sliced job and filament into a functional part. The surrounding actors and
             workspace come from ProjectContext and ProjectUseCases. */
      @Figure { file = "context.svg"; caption = "Stakeholders, inputs and outputs at the printer boundary."; }
    }
    view architecture {
      @Section { title = "System architecture"; }
      doc /* The lead design is CoreXYClosedShapedIntegration. The functional paths summarize the six subsystem
             responsibilities and their working interfaces. */
      @Figure { file = "architecture.svg"; caption = "Commands, feedback, motion and power in the lead design."; }
    }
  }
}
