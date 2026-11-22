within ;
package AxisTests "One motion axis: a stepper motor, a 20-tooth belt pulley, a belt and a carriage, checked by check.py against references derived without a simulator"
  model AxisBeltOnly "The carriage released 0.2 mm from rest on the belt (1.26e5 N/m) with the pulley held: the one-mass-one-spring model of the trade study"
    Modelica.Mechanics.Rotational.Components.Fixed pulleyHold;
    Modelica.Mechanics.Rotational.Components.IdealRollingWheel pulley(radius = 0.0063662);
    Modelica.Mechanics.Translational.Components.Spring belt(c = 1.26e5);
    Modelica.Mechanics.Translational.Components.Mass carriage(m = 0.67, s(start = 2e-4, fixed = true), v(start = 0, fixed = true));
  equation
    connect(pulleyHold.flange, pulley.flangeR);
    connect(pulley.flangeT, belt.flange_a);
    connect(belt.flange_b, carriage.flange_a);
    annotation(experiment(StopTime = 0.05));
  end AxisBeltOnly;

  model AxisStepperHold "The same carriage on a stepper motor holding a fixed field angle at 1.5 A: the motor's own stiffness and rotor inertia are part of the axis"
    Elan8.Electronics.Actuation.StepperMotor motor(phaseResistance = 1.6, phaseInductance = 3.4e-3,
      torqueConstant = 0.3, rotorTeeth = 50, rotorInertia = 5.7e-6, supplyVoltage = 24);
    Modelica.Mechanics.Rotational.Components.IdealRollingWheel pulley(radius = 0.0063662);
    Modelica.Mechanics.Translational.Components.Spring belt(c = 1.26e5);
    Modelica.Mechanics.Translational.Components.Mass carriage(m = 0.67, s(start = 2e-4, fixed = true), v(start = 0, fixed = true));
  equation
    motor.fieldAngle = 0;
    motor.currentCommand = 1.5;
    connect(motor.mechanicalOutput, pulley.flangeR);
    connect(pulley.flangeT, belt.flange_a);
    connect(belt.flange_b, carriage.flange_a);
    annotation(experiment(StopTime = 0.05));
  end AxisStepperHold;
end AxisTests;
