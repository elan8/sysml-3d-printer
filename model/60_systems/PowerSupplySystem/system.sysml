/*
 * SPDX-FileCopyrightText: 2026 Elan8
 *
 * The power supply: a 24 V supply for the heaters, the motors and the electronics. Three ratings are compared.
 * The printer must not ask for more than the supply is rated for.
 */
package PowerSupplySystem {
  private import ISQ::*;
  private import SI::*;
  private import ScalarValues::*;

  part def SupplySpecification :> Elan8::SystemsEngineering::SystemSpecification {
    doc /* What the supply offers: how much power it can deliver and what it weighs and costs. */
    attribute ratedPower : PowerValue;
    attribute mass : MassValue;
    attribute cost : Real;                            // euro
  }

  part def Supply360WArchitecture
      :> SupplySpecification, Elan8::SystemsEngineering::SystemArchitecture {
    doc /* A 24 V, 360 W supply. */
    attribute :>> ratedPower = 360 [W];
    attribute :>> mass = 0.9 [kg];
    attribute :>> cost = 28;
  }

  part def Supply480WArchitecture
      :> SupplySpecification, Elan8::SystemsEngineering::SystemArchitecture {
    doc /* A 24 V, 480 W supply. */
    attribute :>> ratedPower = 480 [W];
    attribute :>> mass = 1.1 [kg];
    attribute :>> cost = 38;
  }

  part def Supply600WArchitecture
      :> SupplySpecification, Elan8::SystemsEngineering::SystemArchitecture {
    doc /* A 24 V, 600 W supply. */
    attribute :>> ratedPower = 600 [W];
    attribute :>> mass = 1.4 [kg];
    attribute :>> cost = 52;
  }
}
