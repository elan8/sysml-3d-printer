/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
 *
 * The heated bed: the build plate and its heater. Two designs are compared: a 300 W and a 400 W silicone heater
 * under the same 250 mm aluminium plate. The plate is the same thermal mass; the power sets the heat-up.
 */
package BedSystem {
  private import ISQ::*;
  private import SI::*;
  private import ScalarValues::*;

  part def BedSpecification :> Elan8::SystemsEngineering::SystemSpecification {
    doc /* What the bed offers: its heater power, its thermal mass and what it loses, and how hot it can get. */
    attribute heaterPower : PowerValue;
    attribute thermalMass : Real;                     // J/K, plate, heater and the part on it
    attribute meanLoss : PowerValue;                  // heat lost to the air while heating to 100 degC
    attribute maxTemperature : ThermodynamicTemperatureValue;
    attribute cost : Real;                            // euro
  }

  part def Bed300WArchitecture
      :> BedSpecification, Elan8::SystemsEngineering::SystemArchitecture {
    doc /* A 300 W heater under a 6 mm aluminium plate. */
    attribute :>> heaterPower = 300 [W];
    attribute :>> thermalMass = 950;
    attribute :>> meanLoss = 25 [W];
    attribute :>> maxTemperature = 383.15 [K];        // 110 degC
    attribute :>> cost = 35;
  }

  part def Bed400WArchitecture
      :> BedSpecification, Elan8::SystemsEngineering::SystemArchitecture {
    doc /* A 400 W heater under the same plate: it heats about a quarter faster. */
    attribute :>> heaterPower = 400 [W];
    attribute :>> thermalMass = 950;
    attribute :>> meanLoss = 25 [W];
    attribute :>> maxTemperature = 383.15 [K];        // 110 degC
    attribute :>> cost = 55;
  }
}
