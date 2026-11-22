/*
 * SPDX-FileCopyrightText: 2026 Elan8
 *
 * The motion and heater control: the microcontroller, its motion planner and its heater control, and the safety
 * monitor. Three designs are compared: an 8-bit board with a trapezoidal planner and a PID, a 32-bit board with
 * a jerk-limited planner and an autotuned PID, and a 32-bit board with input shaping, pressure advance,
 * feed-forward heater control and a model-based thermal runaway monitor. The firmware is what a later
 * increment verifies in the loop.
 */
package MotionControlSystem {
  private import ISQ::*;
  private import SI::*;
  private import ScalarValues::*;

  part def ControlSpecification :> Elan8::SystemsEngineering::SystemSpecification {
    doc /* What the control offers: how much of the axes' vibration it removes, how steady it holds the nozzle temperature, how fast it can step the motors and how quickly it spots a heater fault. */
    attribute ringingFactor : Real;                   // residual vibration over what a trapezoidal move leaves
    attribute hotendTemperatureError : Real;          // K, peak deviation of the nozzle temperature while printing at full flow
    attribute maxStepRate : FrequencyValue;           // total step pulses per second the controller can generate per motor
    attribute runawayDetectionTime : DurationValue;
    attribute power : PowerValue;
    attribute cost : Real;                            // euro
  }

  part def BasicControlArchitecture
      :> ControlSpecification, Elan8::SystemsEngineering::SystemArchitecture {
    doc /* An 8-bit microcontroller at 16 MHz: a trapezoidal planner, a PID on the heaters and a runaway check on a long timer. Limited to 30 kHz of steps per motor, no vibration compensation. */
    attribute :>> ringingFactor = 1.0;
    attribute :>> hotendTemperatureError = 2.0;
    attribute :>> maxStepRate = 30 [kilo * Hz];
    attribute :>> runawayDetectionTime = 40 [s];
    attribute :>> power = 10 [W];
    attribute :>> cost = 25;
  }

  part def StandardControlArchitecture
      :> ControlSpecification, Elan8::SystemsEngineering::SystemArchitecture {
    doc /* A 32-bit Cortex-M4 at 168 MHz: a jerk-limited (S-curve) planner that gives the vibration less to excite, and an autotuned PID. */
    attribute :>> ringingFactor = 0.6;
    attribute :>> hotendTemperatureError = 1.2;
    attribute :>> maxStepRate = 200 [kilo * Hz];
    attribute :>> runawayDetectionTime = 20 [s];
    attribute :>> power = 12 [W];
    attribute :>> cost = 45;
  }

  part def AdvancedControlArchitecture
      :> ControlSpecification, Elan8::SystemsEngineering::SystemArchitecture {
    doc /* The 32-bit board with an input shaper tuned to the measured resonance, pressure advance, feed-forward on the heater from the extrusion rate and a thermal runaway monitor that compares the heater's response with a model. */
    attribute :>> ringingFactor = 0.12;
    attribute :>> hotendTemperatureError = 0.6;
    attribute :>> maxStepRate = 200 [kilo * Hz];
    attribute :>> runawayDetectionTime = 8 [s];
    attribute :>> power = 15 [W];
    attribute :>> cost = 60;
    part firmware : PrinterSoftware::PrinterFirmware;
  }
}
