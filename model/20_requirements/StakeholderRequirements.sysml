/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
 *
 * Stakeholder requirements: what the people involved need, in their own words. Where they know a figure
 * it is stated, but nothing here says how it is measured: the measurable system requirements are derived
 * in FdmPrinter::Requirements, and Traceability shows that each need is covered.
 */
package StakeholderNeeds {

  requirement <'USR-001'> 'Fast prints' {
    doc /* Team lead: a typical bracket must come off the printer within the hour, not the next day. */
  }

  requirement <'USR-002'> 'Parts that fit' {
    doc /* Engineer: dimensions must be right to a tenth of a millimetre, so a printed part fits the part it is meant to fit. */
  }

  requirement <'USR-003'> 'Clean surfaces' {
    doc /* Engineer: no ripples behind corners and edges (ghosting), even when the printer is going fast. */
  }

  requirement <'USR-004'> 'Ready quickly' {
    doc /* Engineer: from pressing start to the first layer must take minutes, not a coffee break. */
  }

  requirement <'USR-005'> 'Common materials' {
    doc /* Engineer: it must print PLA, PETG and ABS, which need a hot nozzle and a hot bed. */
  }

  requirement <'USR-006'> 'Quiet enough for an office' {
    doc /* Office neighbour: I share the room with it; it must not drown out a conversation. */
  }

  requirement <'USR-007'> 'Safe to leave running' {
    doc /* Office neighbour and team lead: if a heater or a sensor fails it must switch itself off before anything catches fire. */
  }

  requirement <'USR-008'> 'Fits on a desk' {
    doc /* Team lead: it must stand on a normal desk and not weigh more than one person can carry. */
  }

  requirement <'USR-009'> 'Affordable' {
    doc /* Team lead: it must cost less than a few hundred euros to build so that the team can have several. */
  }

  requirement <'USR-010'> 'Keeps its calibration' {
    doc /* Technician: after calibration it must keep printing right for months, with little maintenance. */
  }

  requirement <'USR-011'> 'Steady extrusion at speed' {
    doc /* Engineer: when it goes fast the nozzle must still melt enough plastic and hold its temperature, or the lines come out thin and weak. */
  }

  requirement <'USR-012'> 'Fits my parts' {
    doc /* Engineer: most of my parts are brackets and housings up to about 25 cm. */
  }
}
