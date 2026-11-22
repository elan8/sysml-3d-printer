/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
 */
package NominalHotendVerification {
  private import SI::*;
  private import PrinterInterfaces::*;
  private import PrinterSoftware::JobSupervisor;
  private import PrinterSupervisionRequirements::NormalWarmupPermission;
  private import HotendThermalPlant::*;

  enum def VerificationMethodKind { test; }
  metadata def VerificationMethod { attribute kind : VerificationMethodKind; }

  verification warmupKeepsHeatPermission {
    doc /* A hotend-only warm-up. Homing is acknowledged and bed readiness remains pending. */
    @VerificationMethod { kind = VerificationMethodKind::test; }
    subject supervisor : JobSupervisor;
    objective { verify NormalWarmupPermission; }
    action stimulus {
      send new StartPrint() to supervisor;
      then send new HomingComplete() to supervisor;
      then accept after 60 [s];
    }
    assert constraint noFalseTrip {
      supervisor.job.phase == JobPhase::preparing
        and supervisor.job.heatPermitted
        and supervisor.job.warmupAlarm == 0
    }
  }
}
