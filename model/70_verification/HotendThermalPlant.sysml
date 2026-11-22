/*
 * SPDX-FileCopyrightText: 2026 Elan8
 * SPDX-License-Identifier: MIT
 */
package HotendThermalPlant {
  private import ISQ::*;
  private import SI::*;
  private import ScalarValues::*;

  port def TemperatureLink {
    out attribute value : ThermodynamicTemperatureValue;
  }
  port def PowerLink {
    out attribute value : PowerValue;
  }

  part def HotendPlant {
    doc /* The linear heat loss matches the prior 4 W mean at half of the 190 K temperature rise. */
    @Elan8::PhysicalModeling::ModelicaModel {
      className = "HotendBench.Hotend";
      resourceUri = "HotendBench.mo";
    }
    attribute ambientTemperature : ThermodynamicTemperatureValue = 298.15 [K];
    attribute heatCapacity : HeatCapacityValue = HotendSystem::HighFlowHotendArchitecture::thermalMass * 1 [J / K];
    attribute lossConductance : ThermalConductanceValue =
      (2.0 * FdmPrinter::Reference::hotendLoss / FdmPrinter::Reference::hotendTargetRise) * 1 [W / K];
    attribute failureTime : DurationValue = 14 [s];
    attribute remainingAuthority : Real;
    port sensor : TemperatureLink;
    port heatCommand : ~PowerLink;
  }

  part def HotendControl {
    @Elan8::PhysicalModeling::ModelicaModel {
      className = "HotendBench.Control";
      resourceUri = "HotendBench.mo";
    }
    attribute ambientTemperature : ThermodynamicTemperatureValue = 298.15 [K];
    attribute targetTemperature : ThermodynamicTemperatureValue = 488.15 [K];
    attribute heaterRating : PowerValue = HotendSystem::HighFlowHotendArchitecture::heaterPower;
    port sensor : ~TemperatureLink;
    port heatCommand : PowerLink;
  }

  part def WarmupRig {
    part hotend : HotendPlant;
    part controller : HotendControl;
    connect controller.heatCommand to hotend.heatCommand;
    connect hotend.sensor to controller.sensor;
  }

  part def NominalWarmup :> WarmupRig {
    part :>> hotend { attribute :>> remainingAuthority = 1; }
  }
  part def WeakHeaterWarmup :> WarmupRig {
    part :>> hotend { attribute :>> remainingAuthority = 0.05; }
  }
}
