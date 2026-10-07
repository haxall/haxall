# Know Project Haystack

Project Haystack is an ontology for modeling the built environment,
organized into the `ph`, `ph.equips.sugar`, `ph.points`,
`ph.points.sugar`, and `ph.elec` xeto libs.

# Entity Hierarchy

All Haystack entities extend `PhEntity` and are linked by refs:

```
Site                     // building or facility
  System                 // electrical system, air conditioning system, etc
  Space                  // floor, room, or zone
  Equip                  // physical or logical equipment
    Point                // sensor, command, or setpoint
```

Every entity has `id` and a display name. Sites and weather
stations use `dis` directly.
Equips and points use `navName` with `disMacro` to compute display:

```xeto
// site uses dis directly
dis: "Campus HQ"

// equip display is "$siteRef $navName" → "Campus HQ AHU-1"
navName: "AHU-1"
disMacro: "$siteRef $navName"

// point display is "$equipRef $navName" → "Campus HQ AHU-1 DischargeTemp"
navName: "DischargeTemp"
disMacro: "$equipRef $navName"
```

Systems, spaces, equips, and points all require `siteRef`. Points
reference their equipment via `equipRef`, and equips nest under a
parent equip via `equipRef`. Set `spaceRef` on equips and points
when the location is known.

# Sites

A site is a geographic location, typically one building with a
unique street address.

```xeto
@campus-hq: Site {
  dis: "Campus HQ"
  area: Number 55000ft²
  tz: "New_York"
  geoAddr: "100 Main St, Richmond VA 23220"
  geoCoord: Coord "C(37.55,-77.45)"
  yearBuilt: 1985
}
```

Key slots: `area`, `tz`, `weatherStationRef`, `yearBuilt`,
`primaryFunction`, and `geo*` tags (`geoAddr`, `geoCity`,
`geoState`, `geoCountry`, `geoCoord`, `geoPostalCode`).

# Spaces

Spaces model 3D volumes: floors, rooms, and zones.

```xeto
// floor (ground = floorNum 0, subterranean = negative)
@hq-floor1: Floor {
  navName: "Ground"
  disMacro: "$siteRef $navName"
  siteRef: @campus-hq
  floorNum: 0
}

// room contained by a floor
@hq-room204: Room {
  navName: "Room 204"
  disMacro: "$siteRef $navName"
  siteRef: @campus-hq
  spaceRef: @hq-floor1
}
```

Space subtypes:
- `Floor` (with `floorNum`), `GroundFloor`, `SubterraneanFloor`, `RoofFloor`
- `Room`
- `ZoneSpace`, `HvacZoneSpace`, `LightingZoneSpace`
- `DataCenter`

# Equipment

Equipment assets model physical or logical devices.

```xeto
@hq-ahu1: Ahu {
  navName: "AHU-1"
  disMacro: "$siteRef $navName"
  siteRef: @campus-hq
  spaceRef: @hq-floor1
  elecRef: @hq-elec-hvac
  chilledWaterCooling
  hotWaterHeating
  vavZone
  singleDuct
  variableAirVolume
}

@hq-vav1: Vav {
  navName: "VAV-1A"
  disMacro: "$siteRef $navName"
  siteRef: @campus-hq
  equipRef: @hq-ahu1
  airRef: @hq-ahu1
  spaceRef: @hq-room204
  hotWaterHeating
  singleDuct
  series
  pressureIndependent
}

// RTU: rooftop unit with DX cooling and electric heat
@store-rtu1: Rtu {
  navName: "RTU-1"
  disMacro: "$siteRef $navName"
  siteRef: @store
  dxCooling
  elecHeating
  directZone
  singleDuct
  variableAirVolume
}
```

## Common Equipment Types

A rec's `spec` tag is its type: display it with
`spec(rec->spec).specName`, never by inferring a type from markers.

HVAC Air Side:
- `Ahu` - air handling unit (subtypes: `Rtu`, `Doas`, `Mau`)
- `Fcu` - fan coil unit (subtype: `Crac`)
- `Vav` - variable air volume terminal
- `Cav` - constant air volume terminal

HVAC Plant:
- `Chiller`, `Boiler` (`HotWaterBoiler`, `SteamBoiler`)
- `CoolingTower`, `HeatExchanger`
- `Plant` (`ChilledWaterPlant`, `HotWaterPlant`, `SteamPlant`)

Mechanical:
- `Motor` (`AcMotor`, `DcMotor`)
- `Damper`, `DamperActuator`
- `Valve`, `ValveActuator`

Electrical:
- `Meter` (`AcElecMeter`, `DcElecMeter`, `FlowMeter`)
- `ElecPanel`, `Circuit`
- `Battery`, `Ups`

Other:
- `Tank`, `Thermostat`, `Luminaire`, `Pipe`, `Duct`

## Equipment Choices

Choice types constrain equipment properties. Process markers go on
the equipment, not its points.

HeatingProcess (multiChoice on AHU): `hotWaterHeating`,
`steamHeating`, `elecHeating`, `naturalGasHeating`, `dxHeating`

CoolingProcess (multiChoice on AHU): `chilledWaterCooling`,
`dxCooling`, `airCooling`, `waterCooling`

Other choices:
- `ChillerMechanism`: `centrifugal`, `reciprocal`, `rotaryScrew`, `absorption`
- `DuctSection`: `discharge`, `return`, `mixed`, `outside`, `exhaust`, `inlet`
- `PipeSection`: `entering`, `leaving`, `circ`, `bypass`, `header`
- `VavModulation`: `pressureDependent`, `pressureIndependent`
- `VavAirCircuit`: `series`, `parallel`
- `MeterScope`: `siteMeter`, `submeter`

# Points

Points are sensors, commands, or setpoints (see know-point for the
cur/his/writable runtime model).

## Point Function

Every point has exactly one function marker:
- `sensor` - input, AI/BI (read-only measurement)
- `cmd` - command, AO/BO (writable output)
- `sp` - setpoint, soft point, schedule

## Point Kinds

Points are classified by data type via `kind`:
- `"Bool"` - digital/binary (use `enum` for labels: `"off,on"`)
- `"Number"` - analog (requires `unit`)
- `"Str"` - enumerated multi-state (requires `enum`)

## Point Examples

```xeto
// discharge air temp sensor on an AHU
@hq-ahu1-dat: DischargeAirTempSensor {
  navName: "DischargeTemp"
  disMacro: "$equipRef $navName"
  siteRef: @campus-hq
  equipRef: @hq-ahu1
}

// manual point definition (when no predefined spec exists)
@hq-ahu1-filter-dp: NumberPoint {
  navName: "FilterDP"
  disMacro: "$equipRef $navName"
  siteRef: @campus-hq
  equipRef: @hq-ahu1
  sensor
  filter
  pressure
  delta
  unit: "inH₂O"
}
```

## Point Type Composition

Point specs in `ph.points` combine quantity, subject, and function
via intersection types; `ph.points.sugar` adds named specializations:

```xeto
FluidTempPoint : NumberPoint <abstract> { temp, ... }   // ph.points
FluidTempSensor : FluidTempPoint & SensorPoint          // ph.points
AirTempSensor : FluidTempSensor { air }                 // ph.points
DuctAirTempSensor : AirTempSensor { ductSection: DuctSection }
DischargeAirTempSensor : DuctAirTempSensor <sugar> { discharge }
```

Common predefined point types include:
- Air temp: `DischargeAirTempSensor`, `ReturnAirTempSensor`,
  `ZoneAirTempSensor`, `MixedAirTempSensor`, `OutsideAirTempSensor`
- Air temp setpoints: `ZoneAirTempOccCoolingSp`, `ZoneAirTempOccHeatingSp`,
  `ZoneAirTempEffectiveSp`, `DischargeAirTempSp`
- Fan: `FanRunSensor`, `FanRunCmd`, `DischargeFanRunCmd`,
  `FanSpeedModulatingSensor`, `DischargeFanSpeedModulatingCmd`
- Damper: `DamperModulatingCmd`, `DamperOpenCmd`,
  `DischargeAirDamperModulatingCmd`
- Valve: `ValveModulatingCmd`, `ValveOpenCmd`,
  `HotWaterValveModulatingCmd`
- Air flow: `DischargeAirFlowSensor`, `DischargeAirFlowSp`
- Elec (`ph.elec`): `ElecDemandSensor`, `ElecEnergySensor`

When no predefined point type exists, use `NumberPoint`, `BoolPoint`,
or `EnumPoint` directly and add the appropriate marker tags.

# Meters

Meters are equipment that measure substance or energy flow.

```xeto
// main site electric meter
@hq-main-meter: AcElecMeter {
  navName: "ElecMeter-Main"
  disMacro: "$siteRef $navName"
  siteRef: @campus-hq
  siteMeter
}

// HVAC submeter
@hq-hvac-meter: AcElecMeter {
  navName: "ElecMeter-Hvac"
  disMacro: "$siteRef $navName"
  siteRef: @campus-hq
  submeterOf: @hq-main-meter
}

// natural gas meter
@hq-gas-meter: NaturalGasMeter {
  navName: "GasMeter-Main"
  disMacro: "$siteRef $navName"
  siteRef: @campus-hq
  siteMeter
}
```

All meters define `siteMeter` (main) or `submeterOf` (submeter
referencing parent). Use `elecRef`, `naturalGasRef`, `chilledWaterRef`,
`hotWaterRef`, `steamRef` on loads to reference their upstream meter.

# Systems

Systems logically group equipment serving a common purpose.
Equipment references systems via `systemRef`:

```xeto
@hq-chw-sys: ChilledWaterSystem {
  navName: "Chilled Water System"
  disMacro: "$siteRef $navName"
  siteRef: @campus-hq
}
```

System types: `ChilledWaterSystem`, `HotWaterSystem`, `SteamSystem`,
`CondenserWaterSystem`, `ElecSystem`, `AirConditioningSystem`

# Ref Relationships

Key reference tags that link entities:

| Tag | Type | Links |
|-----|------|-------|
| `siteRef` | `ContainedByRef<of:Site>` | entity to its site |
| `spaceRef` | `ContainedByRef<of:Space>` | entity to its space |
| `equipRef` | `ContainedByRef<of:Equip>` | entity to parent equip |
| `systemRef` | `MemberOfRef<of:System>` | entity to systems |
| `airRef` | `FedByRef<medium:Air>` | VAV/terminal to AHU |
| `elecRef` | `FedByRef<medium:Elec>` | load to electric meter |
| `hotWaterRef` | `FedByRef<medium:HotWater>` | load to hot water source |
| `chilledWaterRef` | `FedByRef<medium:ChilledWater>` | load to chilled water source |
| `submeterOf` | `Ref<of:Meter>` | submeter to parent meter |

Reading relationships:
- `spaceRef` on an equip is where it is located - one space by
  design - never the spaces it serves
- `airRef` on a space is the terminal unit that serves it: query
  served spaces as `readAll(space and airRef==@vav)`, not from the
  VAV's `spaceRef`

# Xeto vs Haystack Fidelity

The examples above use xeto instance syntax. Stored in folio they
flatten to Haystack dicts: the `spec` tag is a Ref to the type, typed
scalars like `TimeZone` become plain strings, and non-maybe markers
from the spec hierarchy become tags:

```
id: @campus-hq
spec: @ph::Site
dis: "Campus HQ"
area: 55000ft²
tz: "New_York"
site              // from Site spec
```
