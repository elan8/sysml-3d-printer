/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
 */
package WeakHeaterVerification {
  private import SI::*;
  private import PrinterInterfaces::*;
  private import PrinterSoftware::JobSupervisor;
  private import PrinterSupervisionRequirements::ReportedFaultResponse;
  private import HotendThermalPlant::*;

  enum def VerificationMethodKind { test; }
  metadata def VerificationMethod { attribute kind : VerificationMethodKind; }

  verification weakHeaterRevokesPermission {
    doc /* The plant loses heater authority at 14 s. The supervisor has 10 s from that point to inhibit heat. */
    @VerificationMethod { kind = VerificationMethodKind::test; }
    subject supervisor : JobSupervisor;
    objective { verify ReportedFaultResponse; }
    action stimulus {
      send new StartPrint() to supervisor;
      then send new HomingComplete() to supervisor;
      then accept after 24 [s];
    }
    assert constraint reportsFaultAndInhibitsOutputs {
      supervisor.job.phase == JobPhase::fault
        and supervisor.job.motionRequest == MotionMode::stop
        and supervisor.job.heatPermitted == false
        and supervisor.job.warmupAlarm > 0.5
    }
  }
}
