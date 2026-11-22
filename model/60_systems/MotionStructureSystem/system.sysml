/*
 * SPDX-FileCopyrightText: 2026 Elan8
 *
 * The motion structure: frame, linear guides, belts and the way the toolhead and the bed move. Three designs are
 * compared: a CoreXY on an aluminium extrusion frame, a CoreXY with wide belts on a steel sheet frame, and a
 * bed-slinger where the bed carries the part along Y. What matters is the moving mass of the worst axis and the
 * stiffness between the motor and the nozzle: together they set the first resonance (A-MECH-1).
 */
package MotionStructureSystem {
  private import ISQ::*;
  private import SI::*;
  private import ScalarValues::*;

  part def StructureSpecification :> Elan8::SystemsEngineering::SystemSpecification {
    doc /* What the structure offers: the build volume it encloses, its footprint and mass, what moves and how stiffly, and the errors it adds. */
    attribute buildX : LengthValue;
    attribute buildY : LengthValue;
    attribute buildZ : LengthValue;
    attribute footprintWidth : LengthValue;
    attribute footprintDepth : LengthValue;
    attribute mass : MassValue;                       // frame, guides, belts, bed carriage and gantry, without the motors, hotend and supply
    attribute movingMass : MassValue;                 // of the worst axis, without the hotend
    attribute toolheadShare : Real;                   // 1 when the hotend rides on the worst axis, 0 when it does not
    attribute stiffness : Real;                       // N/m, motor to nozzle on the worst axis: belts in series with the frame
    attribute beltSpeedFactor : Real;                 // belt speed over toolhead speed at the worst move: 1.414 for a CoreXY diagonal
    attribute motorForceFactor : Real;                // toolhead force over the force of one motor
    attribute expansionCoefficient : Real;            // 1/K, of the frame
    attribute geometryError : LengthValue;            // squareness and straightness over the build volume
    attribute cost : Real;                            // euro
  }

  part def CoreXYExtrusionArchitecture
      :> StructureSpecification, Elan8::SystemsEngineering::SystemArchitecture {
    doc /* A CoreXY with 6 mm belts on a 2020 aluminium extrusion frame. Both motors move the light toolhead; the bed only moves in Z. */
    attribute :>> buildX = 250 [mm];
    attribute :>> buildY = 250 [mm];
    attribute :>> buildZ = 250 [mm];
    attribute :>> footprintWidth = 440 [mm];
    attribute :>> footprintDepth = 440 [mm];
    attribute :>> mass = 7.5 [kg];
    attribute :>> movingMass = 0.55 [kg];
    attribute :>> toolheadShare = 1.0;
    attribute :>> stiffness = 1.26e5;
    attribute :>> beltSpeedFactor = 1.414;
    attribute :>> motorForceFactor = 1.4;
    attribute :>> expansionCoefficient = 23e-6;
    attribute :>> geometryError = 40 [micro * m];
    attribute :>> cost = 190;
  }

  part def CoreXYWideSheetArchitecture
      :> StructureSpecification, Elan8::SystemsEngineering::SystemArchitecture {
    doc /* A CoreXY with 9 mm belts on a bent-steel sheet frame. Stiffer and straighter, and it grows less with temperature, but heavier and dearer. */
    attribute :>> buildX = 250 [mm];
    attribute :>> buildY = 250 [mm];
    attribute :>> buildZ = 250 [mm];
    attribute :>> footprintWidth = 450 [mm];
    attribute :>> footprintDepth = 450 [mm];
    attribute :>> mass = 9.8 [kg];
    attribute :>> movingMass = 0.62 [kg];
    attribute :>> toolheadShare = 1.0;
    attribute :>> stiffness = 2.0e5;
    attribute :>> beltSpeedFactor = 1.414;
    attribute :>> motorForceFactor = 1.4;
    attribute :>> expansionCoefficient = 12e-6;
    attribute :>> geometryError = 25 [micro * m];
    attribute :>> cost = 300;
  }

  part def BedSlingerArchitecture
      :> StructureSpecification, Elan8::SystemsEngineering::SystemArchitecture {
    doc /* A bed-slinger on an extrusion frame: the toolhead moves in X and Z, the bed with the part moves in Y. Simple and cheap, but the bed and the part are a large moving mass on a single belt. */
    attribute :>> buildX = 250 [mm];
    attribute :>> buildY = 250 [mm];
    attribute :>> buildZ = 250 [mm];
    attribute :>> footprintWidth = 430 [mm];
    attribute :>> footprintDepth = 560 [mm];
    attribute :>> mass = 8.6 [kg];
    attribute :>> movingMass = 1.6 [kg];
    attribute :>> toolheadShare = 0.0;
    attribute :>> stiffness = 0.9e5;
    attribute :>> beltSpeedFactor = 1.0;
    attribute :>> motorForceFactor = 1.0;
    attribute :>> expansionCoefficient = 23e-6;
    attribute :>> geometryError = 60 [micro * m];
    attribute :>> cost = 150;
  }
}
