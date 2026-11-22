// SPDX-FileCopyrightText: 2026 Elan8
// SPDX-License-Identifier: MIT
within ;
package HotendBench
  connector TemperatureSignal
    Real value(unit = "K");
  end TemperatureSignal;

  connector PowerSignal
    Real value(unit = "W");
  end PowerSignal;

  model Hotend "Lumped hotend with commanded and delivered heater power"
    parameter Real ambientTemperature(unit = "K");
    parameter Real heatCapacity(unit = "J/K");
    parameter Real lossConductance(unit = "W/K");
    parameter Real failureTime(unit = "s");
    parameter Real remainingAuthority;
    PowerSignal heatCommand;
    TemperatureSignal sensor;
    output Real temperature(unit = "K", start = ambientTemperature, fixed = true);
    output Real deliveredPower(unit = "W");
    output Real faultActive;
  equation
    faultActive = if remainingAuthority < 1 and time >= failureTime then 1 else 0;
    deliveredPower = heatCommand.value * (if faultActive > 0.5 then remainingAuthority else 1);
    heatCapacity * der(temperature) = deliveredPower - lossConductance * (temperature - ambientTemperature);
    sensor.value = temperature;
  end Hotend;

  model Thermostat "Sampled heat request; the supervisor's permission gates the resulting power command"
    parameter Real targetTemperature(unit = "K");
    parameter Real heaterRating(unit = "W");
    input Real temperature(unit = "K");
    input Real heatPermit;
    output Real commandedPower(unit = "W");
    output Real reachedTarget;
    discrete Boolean requestHeat(start = true, fixed = true);
    discrete Boolean reached(start = false, fixed = true);
  equation
    when sample(0.25, 0.25) then
      requestHeat = if temperature <= targetTemperature - 0.5 then true
        else if temperature >= targetTemperature + 0.5 then false else pre(requestHeat);
      reached = pre(reached) or temperature >= targetTemperature;
    end when;
    commandedPower = if heatPermit > 0.5 and requestHeat then heaterRating else 0;
    reachedTarget = if reached then 1 else 0;
  end Thermostat;

  model WarmupWatchdog "Uses only observed temperature and requested heater power"
    parameter Real ambientTemperature(unit = "K");
    parameter Real targetTemperature(unit = "K");
    parameter Real heaterRating(unit = "W");
    input Real temperature(unit = "K");
    input Real commandedPower(unit = "W");
    output Real alarm;
    discrete Real windowStart(unit = "K", start = ambientTemperature, fixed = true);
    discrete Boolean armed(start = false, fixed = true);
    discrete Boolean latched(start = false, fixed = true);
  equation
    when sample(4, 4) then
      latched = pre(latched) or (pre(armed) and commandedPower >= heaterRating
        and temperature < targetTemperature - 5 and temperature - pre(windowStart) < 4);
      windowStart = temperature;
      armed = commandedPower >= heaterRating and temperature < targetTemperature - 5;
    end when;
    alarm = if latched then 1 else 0;
  end WarmupWatchdog;

  model Control "Modeled temperature controller and warm-up watchdog"
    parameter Real ambientTemperature(unit = "K");
    parameter Real targetTemperature(unit = "K");
    parameter Real heaterRating(unit = "W");
    input Real heatPermit;
    input Real supervisorPhase "Sampled observer channel; independent of the thermal equations";
    TemperatureSignal sensor;
    PowerSignal heatCommand;
    Thermostat thermostat(targetTemperature = targetTemperature, heaterRating = heaterRating);
    WarmupWatchdog watchdog(
      ambientTemperature = ambientTemperature, targetTemperature = targetTemperature, heaterRating = heaterRating);
    output Real commandedPower(unit = "W");
    output Real reachedTarget;
    output Real warmupAlarm;
  equation
    thermostat.heatPermit = heatPermit;
    thermostat.temperature = sensor.value;
    watchdog.temperature = sensor.value;
    watchdog.commandedPower = thermostat.commandedPower;
    heatCommand.value = thermostat.commandedPower;
    commandedPower = thermostat.commandedPower;
    reachedTarget = thermostat.reachedTarget;
    warmupAlarm = watchdog.alarm;
  end Control;
end HotendBench;
