/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
 */
package PrinterInterfaces {
  private import ScalarValues::*;

  enum def JobPhase {
    idle; preparing; printing; pausing; paused; cooling; complete; cancelled; fault;
  }

  enum def MotionMode { stop; home; runToolpath; hold; }

  item def StartPrint {
    doc /* The job adapter emits this after a sliced job and its material profile have been accepted. */
  }
  item def PausePrint;
  item def ResumePrint;
  item def CancelPrint;
  item def AcknowledgeResult;
  item def ResetFault;

  item def HomingComplete;
  item def MotionHeld {
    doc /* The motion executor has reached its hold point and can preserve position in the toolpath. */
  }
  item def ToolpathComplete {
    doc /* The toolpath is exhausted and motion is quiescent. */
  }
  item def MotionStopped {
    doc /* The motion executor acknowledges a stop request, including when it was already stationary. */
  }
  item def AtPrintTemperature {
    doc /* The hotend and bed both meet the selected job profile's readiness criteria. */
  }
  item def TemperatureNotReady;
  item def CooldownComplete {
    doc /* After heat permission is revoked, the thermal controller reports when the temperatures permit job
           removal. It reports immediately if they already permit removal. */
  }
  item def HeaterFault;
  item def RecoveryConfirmed {
    doc /* The safety monitor confirms the fault is clear and the printer is stationary and cooled. */
  }

  port def OperatorJobPort {
    in item start : StartPrint;
    in item pause : PausePrint;
    in item resume : ResumePrint;
    in item cancel : CancelPrint;
    in item acknowledge : AcknowledgeResult;
    in item reset : ResetFault;
    out attribute phase : JobPhase;
  }

  port def SupervisorMotionPort {
    out attribute requestedMode : MotionMode;
    in item homed : HomingComplete;
    in item held : MotionHeld;
    in item finished : ToolpathComplete;
    in item stopped : MotionStopped;
  }

  port def SupervisorThermalPort {
    out attribute heatPermitted : Boolean;
    in item ready : AtPrintTemperature;
    in item notReady : TemperatureNotReady;
    in item cooled : CooldownComplete;
  }

  port def SupervisorSafetyPort {
    in item fault : HeaterFault;
    in item recoveryConfirmed : RecoveryConfirmed;
  }
}
