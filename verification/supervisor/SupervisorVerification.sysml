/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
 */
package SupervisorVerification {
  private import SI::*;
  private import PrinterInterfaces::*;
  private import PrinterSoftware::JobSupervisor;
  private import PrinterSupervisionRequirements::*;

  enum def VerificationMethodKind { test; }
  metadata def VerificationMethod { attribute kind : VerificationMethodKind; }

  verification completesPrint {
    @VerificationMethod { kind = VerificationMethodKind::test; }
    subject supervisor : JobSupervisor;
    objective { verify PrintInterlocks; }
    action stimulus {
      send new StartPrint() to supervisor;
      then send new AtPrintTemperature() to supervisor;
      then send new HomingComplete() to supervisor;
      then send new ToolpathComplete() to supervisor;
      then send new CooldownComplete() to supervisor;
    }
    assert constraint completedWithOutputsOff {
      supervisor.job.phase == JobPhase::complete
        and supervisor.job.motionRequest == MotionMode::stop
        and supervisor.job.heatPermitted == false
    }
  }

  verification heaterFaultDuringPrint {
    @VerificationMethod { kind = VerificationMethodKind::test; }
    subject supervisor : JobSupervisor;
    objective { verify ReportedFaultResponse; }
    action stimulus {
      send new StartPrint() to supervisor;
      then send new HomingComplete() to supervisor;
      then send new AtPrintTemperature() to supervisor;
      then accept after 2 [s];
      then send new HeaterFault() to supervisor;
    }
    assert constraint faultsWithOutputsInhibited {
      supervisor.job.phase == JobPhase::fault
        and supervisor.job.motionRequest == MotionMode::stop
        and supervisor.job.heatPermitted == false
    }
  }

  verification waitsForTemperature {
    @VerificationMethod { kind = VerificationMethodKind::test; }
    subject supervisor : JobSupervisor;
    objective { verify PrintInterlocks; }
    action stimulus {
      send new StartPrint() to supervisor;
      then send new HomingComplete() to supervisor;
    }
    assert constraint preheatsWithoutRunningToolpath {
      supervisor.job.phase == JobPhase::preparing
        and supervisor.job.motionRequest == MotionMode::stop
        and supervisor.job.heatPermitted
    }
  }

  verification waitsForHoming {
    @VerificationMethod { kind = VerificationMethodKind::test; }
    subject supervisor : JobSupervisor;
    objective { verify PrintInterlocks; }
    action stimulus {
      send new StartPrint() to supervisor;
      then send new AtPrintTemperature() to supervisor;
    }
    assert constraint staysInHoming {
      supervisor.job.phase == JobPhase::preparing
        and supervisor.job.motionRequest == MotionMode::home
    }
  }

  verification waitsForMotionHold {
    @VerificationMethod { kind = VerificationMethodKind::test; }
    subject supervisor : JobSupervisor;
    objective { verify PrintInterlocks; }
    action stimulus {
      send new StartPrint() to supervisor;
      then send new HomingComplete() to supervisor;
      then send new AtPrintTemperature() to supervisor;
      then send new PausePrint() to supervisor;
      then send new ResumePrint() to supervisor;
    }
    assert constraint holdsUntilMotionAcknowledges {
      supervisor.job.phase == JobPhase::pausing and supervisor.job.motionRequest == MotionMode::hold
    }
  }

  verification temperatureLossBlocksResume {
    @VerificationMethod { kind = VerificationMethodKind::test; }
    subject supervisor : JobSupervisor;
    objective { verify PrintInterlocks; }
    action stimulus {
      send new StartPrint() to supervisor;
      then send new HomingComplete() to supervisor;
      then send new AtPrintTemperature() to supervisor;
      then send new TemperatureNotReady() to supervisor;
      then send new MotionHeld() to supervisor;
      then send new ResumePrint() to supervisor;
    }
    assert constraint remainsPaused {
      supervisor.job.phase == JobPhase::paused and supervisor.job.motionRequest == MotionMode::hold
    }
  }

  verification resumesAfterTemperatureReturns {
    @VerificationMethod { kind = VerificationMethodKind::test; }
    subject supervisor : JobSupervisor;
    objective { verify PrintInterlocks; }
    action stimulus {
      send new StartPrint() to supervisor;
      then send new HomingComplete() to supervisor;
      then send new AtPrintTemperature() to supervisor;
      then send new TemperatureNotReady() to supervisor;
      then send new AtPrintTemperature() to supervisor;
      then send new MotionHeld() to supervisor;
      then send new ResumePrint() to supervisor;
    }
    assert constraint resumesToolpath {
      supervisor.job.phase == JobPhase::printing and supervisor.job.motionRequest == MotionMode::runToolpath
    }
  }

  verification cancelWaitsForMotionStop {
    @VerificationMethod { kind = VerificationMethodKind::test; }
    subject supervisor : JobSupervisor;
    objective { verify PrintInterlocks; }
    action stimulus {
      send new StartPrint() to supervisor;
      then send new CancelPrint() to supervisor;
      then send new CooldownComplete() to supervisor;
    }
    assert constraint stillCoolingUntilStopConfirmation {
      supervisor.job.phase == JobPhase::cooling
        and supervisor.job.motionRequest == MotionMode::stop
        and supervisor.job.heatPermitted == false
    }
  }

  verification completedToolpathWaitsForCooldown {
    @VerificationMethod { kind = VerificationMethodKind::test; }
    subject supervisor : JobSupervisor;
    objective { verify PrintInterlocks; }
    action stimulus {
      send new StartPrint() to supervisor;
      then send new HomingComplete() to supervisor;
      then send new AtPrintTemperature() to supervisor;
      then send new ToolpathComplete() to supervisor;
    }
    assert constraint coolsBeforeReportingCompletion {
      supervisor.job.phase == JobPhase::cooling
        and supervisor.job.motionRequest == MotionMode::stop
        and supervisor.job.heatPermitted == false
    }
  }

  verification reportsCancellationAfterStopAndCooldown {
    @VerificationMethod { kind = VerificationMethodKind::test; }
    subject supervisor : JobSupervisor;
    objective { verify PrintInterlocks; }
    action stimulus {
      send new StartPrint() to supervisor;
      then send new HomingComplete() to supervisor;
      then send new AtPrintTemperature() to supervisor;
      then send new CancelPrint() to supervisor;
      then send new MotionStopped() to supervisor;
      then send new CooldownComplete() to supervisor;
    }
    assert constraint cancelledWithOutputsOff {
      supervisor.job.phase == JobPhase::cancelled
        and supervisor.job.motionRequest == MotionMode::stop
        and supervisor.job.heatPermitted == false
    }
  }

  verification newFaultInvalidatesRecovery {
    @VerificationMethod { kind = VerificationMethodKind::test; }
    subject supervisor : JobSupervisor;
    objective { verify ReportedFaultResponse; }
    action stimulus {
      send new StartPrint() to supervisor;
      then send new HeaterFault() to supervisor;
      then send new RecoveryConfirmed() to supervisor;
      then send new HeaterFault() to supervisor;
      then send new ResetFault() to supervisor;
      then send new StartPrint() to supervisor;
    }
    assert constraint faultStaysLatched {
      supervisor.job.phase == JobPhase::fault
        and supervisor.job.motionRequest == MotionMode::stop
        and supervisor.job.heatPermitted == false
    }
  }

  verification resetRequiresOperatorAction {
    @VerificationMethod { kind = VerificationMethodKind::test; }
    subject supervisor : JobSupervisor;
    objective { verify ReportedFaultResponse; }
    action stimulus {
      send new StartPrint() to supervisor;
      then send new HeaterFault() to supervisor;
      then send new RecoveryConfirmed() to supervisor;
      then send new StartPrint() to supervisor;
    }
    assert constraint staysStoppedAfterRecoveryConfirmation {
      supervisor.job.phase == JobPhase::fault
        and supervisor.job.motionRequest == MotionMode::stop
        and supervisor.job.heatPermitted == false
    }
  }

  verification acceptsNewPrintAfterConfirmedReset {
    @VerificationMethod { kind = VerificationMethodKind::test; }
    subject supervisor : JobSupervisor;
    objective { verify ReportedFaultResponse; }
    action stimulus {
      send new StartPrint() to supervisor;
      then send new HeaterFault() to supervisor;
      then send new RecoveryConfirmed() to supervisor;
      then send new ResetFault() to supervisor;
      then send new StartPrint() to supervisor;
    }
    assert constraint acceptsANewJob {
      supervisor.job.phase == JobPhase::preparing
        and supervisor.job.motionRequest == MotionMode::home
        and supervisor.job.heatPermitted
    }
  }
}
