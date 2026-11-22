// SPDX-FileCopyrightText: 2026 Elan8
// SPDX-License-Identifier: MIT
within ;
model CoreXYTransmission "Ideal CoreXY routing between the elastic belts and the carriage"
  Modelica.Mechanics.Translational.Interfaces.Flange_a beltA;
  Modelica.Mechanics.Translational.Interfaces.Flange_a beltB;
  Modelica.Mechanics.Translational.Interfaces.Flange_b carriageX;
  Modelica.Mechanics.Translational.Interfaces.Flange_b carriageY;
equation
  beltA.s = carriageX.s + carriageY.s;
  beltB.s = carriageX.s - carriageY.s;
  // Dual of the displacement transform: the power entering all four flanges sums to zero.
  carriageX.f = -(beltA.f + beltB.f);
  carriageY.f = -(beltA.f - beltB.f);
end CoreXYTransmission;
