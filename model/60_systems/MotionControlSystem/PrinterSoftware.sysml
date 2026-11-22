/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
 */
package PrinterSoftware {
  private import ScalarValues::*;
  private import Elan8::Software::*;
  private import PrinterInterfaces::*;

  part def JobSupervisor :> SoftwareModule {
    port operator : OperatorJobPort;
    port motion : SupervisorMotionPort;
    port thermal : SupervisorThermalPort;
    port safety : SupervisorSafetyPort;
    bind operator.phase = job.phase;
    bind motion.requestedMode = job.motionRequest;
    bind thermal.heatPermitted = job.heatPermitted;

    state job {
      attribute phase : JobPhase := JobPhase::idle;
      attribute motionRequest : MotionMode := MotionMode::stop;
      attribute heatPermitted : Boolean := false;
      attribute axesHomed : Boolean := false;
      attribute temperaturesReady : Boolean := false;
      attribute axesStopped : Boolean := false;
      attribute cooled : Boolean := false;
      attribute cancelledJob : Boolean := false;
      attribute resetPermitted : Boolean := false;

      entry;
      then idle;

      state idle {
        entry action clearJob {
          assign phase := JobPhase::idle;
          then assign motionRequest := MotionMode::stop;
          then assign heatPermitted := false;
          then assign axesHomed := false;
          then assign temperaturesReady := false;
          then assign axesStopped := false;
          then assign cooled := false;
          then assign cancelledJob := false;
          then assign resetPermitted := false;
        }
      }
      state preparing {
        entry action reportPreparing { assign phase := JobPhase::preparing; }
      }
      state printing {
        entry action runMotion {
          assign phase := JobPhase::printing;
          then assign motionRequest := MotionMode::runToolpath;
        }
      }
      state pausing {
        entry action requestHold {
          assign phase := JobPhase::pausing;
          then assign motionRequest := MotionMode::hold;
        }
      }
      state paused {
        entry action reportPaused { assign phase := JobPhase::paused; }
      }
      state cooling {
        entry action stopAndCool {
          assign phase := JobPhase::cooling;
          then assign heatPermitted := false;
          then assign motionRequest := MotionMode::stop;
        }
      }
      state complete {
        entry action reportComplete { assign phase := JobPhase::complete; }
      }
      state cancelled {
        entry action reportCancelled { assign phase := JobPhase::cancelled; }
      }
      state fault {
        entry action inhibitOutputs {
          assign heatPermitted := false;
          then assign motionRequest := MotionMode::stop;
          then assign phase := JobPhase::fault;
        }
      }

      transition start first idle accept StartPrint
        do action {
          assign motionRequest := MotionMode::home;
          then assign heatPermitted := true;
        }
        then preparing;
      transition homeDone first preparing accept HomingComplete
        do action {
          assign axesHomed := true;
          then assign motionRequest := MotionMode::stop;
        }
        then preparing;
      transition thermalReady first preparing accept AtPrintTemperature
        do action { assign temperaturesReady := true; }
        then preparing;
      transition thermalNotReady first preparing accept TemperatureNotReady
        do action { assign temperaturesReady := false; }
        then preparing;
      transition beginToolpath first preparing accept when axesHomed and temperaturesReady
        then printing;

      transition pause first printing accept PausePrint then pausing;
      transition holdReached first pausing accept MotionHeld then paused;
      transition holdTemperatureReady first paused accept AtPrintTemperature
        do action { assign temperaturesReady := true; }
        then paused;
      transition holdTemperatureLost first paused accept TemperatureNotReady
        do action { assign temperaturesReady := false; }
        then paused;
      transition pausingTemperatureLost first pausing accept TemperatureNotReady
        do action { assign temperaturesReady := false; }
        then pausing;
      transition pausingTemperatureReady first pausing accept AtPrintTemperature
        do action { assign temperaturesReady := true; }
        then pausing;
      transition resume first paused accept ResumePrint
        if temperaturesReady
        then printing;
      transition printingTemperatureLost first printing accept TemperatureNotReady
        do action { assign temperaturesReady := false; }
        then pausing;

      transition finish first printing accept ToolpathComplete
        do action { assign axesStopped := true; }
        then cooling;
      transition finishWhilePausing first pausing accept ToolpathComplete
        do action { assign axesStopped := true; }
        then cooling;
      transition cancelPreparation first preparing accept CancelPrint
        do action { assign cancelledJob := true; }
        then cooling;
      transition cancelPrinting first printing accept CancelPrint
        do action { assign cancelledJob := true; }
        then cooling;
      transition cancelPausing first pausing accept CancelPrint
        do action { assign cancelledJob := true; }
        then cooling;
      transition cancelPaused first paused accept CancelPrint
        do action { assign cancelledJob := true; }
        then cooling;
      transition stopped first cooling accept MotionStopped
        do action { assign axesStopped := true; }
        then cooling;
      transition cooledDown first cooling accept CooldownComplete
        do action { assign cooled := true; }
        then cooling;
      transition readyForRemoval first cooling accept when axesStopped and cooled and cancelledJob == false
        then complete;
      transition readyAfterCancel first cooling accept when axesStopped and cooled and cancelledJob
        then cancelled;
      transition acknowledgeCompleted first complete accept AcknowledgeResult then idle;
      transition acknowledgeCancelled first cancelled accept AcknowledgeResult then idle;

      transition faultInIdle first idle accept HeaterFault then fault;
      transition faultInPreparation first preparing accept HeaterFault then fault;
      transition faultInPrint first printing accept HeaterFault then fault;
      transition faultInPauseRequest first pausing accept HeaterFault then fault;
      transition faultInPause first paused accept HeaterFault then fault;
      transition faultInCooldown first cooling accept HeaterFault then fault;
      transition faultAfterPrint first complete accept HeaterFault then fault;
      transition faultAfterCancel first cancelled accept HeaterFault then fault;
      transition relatch first fault accept HeaterFault
        do action { assign resetPermitted := false; }
        then fault;
      transition allowReset first fault accept RecoveryConfirmed
        do action { assign resetPermitted := true; }
        then fault;
      transition reset first fault accept ResetFault
        if resetPermitted
        then idle;
    }
  }

  part def JobAdapter :> SoftwareModule {
    doc /* Accepts a prepared job and material profile, forwards operator commands and presents job status. */
    port supervisor : ~OperatorJobPort;
  }

  part def MotionExecution :> SoftwareModule {
    doc /* Owns homing, planning, shaping, drive commands and the hold or stop acknowledgement. */
    port supervisor : ~SupervisorMotionPort;
  }

  part def ThermalControl :> SoftwareModule {
    doc /* Owns nozzle and bed temperature control and reports readiness and cooldown. Heat permission gates its outputs. */
    port supervisor : ~SupervisorThermalPort;
  }

  part def SafetyMonitor :> SoftwareModule {
    doc /* Reports heater faults and confirms the recovery interlock before the operator can reset the supervisor. */
    port supervisor : ~SupervisorSafetyPort;
  }

  part def PrinterFirmware :> SoftwareApplication {
    part jobAdapter : JobAdapter;
    part supervisor : JobSupervisor;
    part motion : MotionExecution;
    part thermal : ThermalControl;
    part safety : SafetyMonitor;
    connect jobAdapter.supervisor to supervisor.operator;
    connect supervisor.motion to motion.supervisor;
    connect supervisor.thermal to thermal.supervisor;
    connect safety.supervisor to supervisor.safety;
  }
}
