/*
 * SPDX-FileCopyrightText: 2026 Elan8
 *
 * The hotend: the heater block, nozzle, thermistor and cooling that melt the filament. Three designs are
 * compared: a standard PTFE-lined hotend, an all-metal hotend, and a high-flow hotend with a larger heater
 * block. Heater power sets the heat-up time and the melt flow; the hotend's mass rides on the axes.
 */
package HotendSystem {
  private import ISQ::*;
  private import SI::*;
  private import ScalarValues::*;

  part def HotendSpecification :> Elan8::SystemsEngineering::SystemSpecification {
    doc /* What the hotend offers: how hot it gets, how fast it heats and how much plastic it can melt per second, and what it adds to the moving mass. */
    attribute mass : MassValue;                       // the toolhead's hotend assembly with its fan and shroud
    attribute heaterPower : PowerValue;
    attribute thermalMass : Real;                     // J/K, heater block, heatbreak end and nozzle
    attribute maxTemperature : ThermodynamicTemperatureValue;
    attribute maxFlow : Real;                         // mm^3/s of PETG
    attribute cost : Real;                            // euro
  }

  part def StandardHotendArchitecture
      :> HotendSpecification, Elan8::SystemsEngineering::SystemArchitecture {
    doc /* A PTFE-lined hotend with a 40 W cartridge. Light and cheap, but limited to 260 degC and a modest melt flow. */
    attribute :>> mass = 0.06 [kg];
    attribute :>> heaterPower = 40 [W];
    attribute :>> thermalMass = 14;
    attribute :>> maxTemperature = 533.15 [K];        // 260 degC
    attribute :>> maxFlow = 12;
    attribute :>> cost = 25;
  }

  part def AllMetalHotendArchitecture
      :> HotendSpecification, Elan8::SystemsEngineering::SystemArchitecture {
    doc /* An all-metal hotend with a 60 W cartridge that reaches 300 degC; it melts about 22 mm^3/s. */
    attribute :>> mass = 0.09 [kg];
    attribute :>> heaterPower = 60 [W];
    attribute :>> thermalMass = 14;
    attribute :>> maxTemperature = 573.15 [K];        // 300 degC
    attribute :>> maxFlow = 22;
    attribute :>> cost = 45;
  }

  part def HighFlowHotendArchitecture
      :> HotendSpecification, Elan8::SystemsEngineering::SystemArchitecture {
    doc /* An all-metal hotend with a larger block, a longer melt zone and an 80 W cartridge: 32 mm^3/s at 300 degC, with a heavier toolhead. */
    attribute :>> mass = 0.12 [kg];
    attribute :>> heaterPower = 80 [W];
    attribute :>> thermalMass = 18;
    attribute :>> maxTemperature = 573.15 [K];        // 300 degC
    attribute :>> maxFlow = 32;
    attribute :>> cost = 80;
  }
}
