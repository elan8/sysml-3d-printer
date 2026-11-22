/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
 */
package PrinterSupervisionRequirements {
  private import FdmPrinter::Requirements;

  requirement <'CTRL-001'> PrintInterlocks {
    doc /* Enable the toolpath after homing and thermal readiness. Report a terminal job status only after
           motion has stopped and cooldown is complete. */
  }

  requirement <'CTRL-002'> ReportedFaultResponse {
    doc /* A reported heater fault revokes heat permission and requests motion stop in the same event.
           A new print becomes available after recovery is confirmed and the operator resets the fault. */
  }

  dependency heaterFaultResponse from ReportedFaultResponse to FdmPrinter::Requirements::'SYS-015';
}
