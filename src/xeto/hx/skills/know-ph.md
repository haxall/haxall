# Know Project Haystack

Project Haystack is an ontology for modeling the built environment.
It defines types for sites, spaces, equipment, and data points
organized into the `ph`, `ph.equips`, and `ph.points` xeto libs.

# Entity Hierarchy

All Haystack entities extend `PhEntity` and are linked by refs:

```
Site                     // building or facility
  System                 // electrial sytem, air conditioning system, etc
  Space                  // floor, room, or zone
  Equip                  // physical or logical equipment
    Point                // sensor, command, or setpoint
```

Every entity has `id` and a display name. Sites use `dis` directly.
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

Child entities reference their parent site via `siteRef`. Equipment
uses `equipRef` for nesting. Points reference their equipment via `equipRef`.

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

Spaces model 3D volumes: floors, rooms, and zones. All spaces
require `siteRef`.

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

// HVAC zone
@hq-zone3b: HvacZoneSpace {
  navName: "Zone 3-B"
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

Equipment assets model physical or logical devices. All equips
require `siteRef`. Use `equipRef` to nest child equipment and
`spaceRef` for location.

```xeto
@hq-ahu1: Ahu {
  navName: "AHU-1"
  disMacro: "$siteRef $navName"
  siteRef: @campus-hq
  spaceRef: @hq-floor1
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

@hq-chiller1: Chiller {
  navName: "Chiller-1"
  disMacro: "$siteRef $navName"
  siteRef: @campus-hq
  coolingCapacity: Number 500ton
}
```

## Common Equipment Types

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
- `Motor` (`FanMotor`, `PumpMotor`)
- `Damper`, `DamperActuator`
- `Valve`, `ValveActuator`

Electrical:
- `Meter` (`AcElecMeter`, `DcElecMeter`, `FlowMeter`)
- `ElecPanel`, `Circuit`
- `Battery`, `Ups`

Other:
- `Tank`, `Thermostat`, `Luminaire`, `Pipe`, `Duct`

## Equipment Choices

Choice types constrain equipment properties. Common ones:

```xeto
// heating/cooling process (multiChoice on AHU)
heatingProcess: HeatingProcess
coolingProcess: CoolingProcess
```

HeatingProcess options: `hotWaterHeating`, `steamHeating`,
`elecHeating`, `naturalGasHeating`, `dxHeating`

CoolingProcess options: `chilledWaterCooling`, `dxCooling`,
`airCooling`, `waterCooling`

Other choices:
- `ChillerMechanism`: `centrifugal`, `reciprocal`, `rotaryScrew`, `absorption`
- `DuctSection`: `discharge`, `return`, `mixed`, `outside`, `exhaust`, `inlet`
- `PipeSection`: `entering`, `leaving`, `circ`, `bypass`, `header`
- `VavModulation`: `pressureDependent`, `pressureIndependent`
- `VavAirCircuit`: `series`, `parallel`
- `MeterScope`: `siteMeter`, `submeter`

# Points

Points are sensors, commands, or setpoints. All points require
`kind` and typically `equipRef` and `siteRef`.

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

// zone air temp sensor
@hq-zone3b-zat: ZoneAirTempSensor {
  navName: "ZoneTemp"
  disMacro: "$equipRef $navName"
  siteRef: @campus-hq
  equipRef: @hq-vav1
  spaceRef: @hq-zone3b
}

// fan run command (boolean)
@hq-ahu1-fan-run: DischargeFanRunCmd {
  navName: "Fan"
  disMacro: "$equipRef $navName"
  siteRef: @campus-hq
  equipRef: @hq-ahu1
}

// zone temp heating setpoint
@hq-zone3b-htg-sp: ZoneAirTempOccHeatingSp {
  navName: "HeatingSP"
  disMacro: "$equipRef $navName"
  siteRef: @campus-hq
  equipRef: @hq-vav1
  spaceRef: @hq-zone3b
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

Point specs combine three dimensions via intersection types:

```xeto
// base quantity type
AirTempPoint: NumberPoint { air, temp, unit:"°F" }

// combine quantity + function
AirTempSensor: AirTempPoint & SensorPoint

// specialize by duct section
DischargeAirTempSensor: AirTempSensor { discharge }
```

Common predefined point types include:
- Air temp: `DischargeAirTempSensor`, `ReturnAirTempSensor`,
  `ZoneAirTempSensor`, `MixedAirTempSensor`, `OutsideAirTempSensor`
- Air temp setpoints: `ZoneAirTempOccCoolingSp`, `ZoneAirTempOccHeatingSp`,
  `ZoneAirTempEffectiveSp`, `DischargeAirTempSp`
- Fan: `FanRunSensor`, `FanRunCmd`, `FanSpeedModulatingSensor`
- Damper: `DamperCmdPoint`, `DamperSensorPoint`
- Valve: `ValveCmdPoint`, `ValveSensorPoint`
- Air flow: `DischargeAirFlowSensor`, `DischargeAirFlowSp`
- Elec: `ElecDemandSensor`, `ElecEnergySensor`

When no predefined point type exists, use `NumberPoint`, `BoolPoint`,
or `EnumPoint` directly and add the appropriate marker tags.

## Cur, His, Writable

Points support three infrastructure capabilities via markers:
- `cur` - real-time current value (`curVal`, `curStatus`)
- `his` - historized time-series data (`hisMode`, `hisTotalized`)
- `writable` - commandable via 16-level priority array (`writeVal`, `writeLevel`)

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
@hq-gas-meter: FlowMeter {
  navName: "GasMeter-Main"
  disMacro: "$siteRef $navName"
  siteRef: @campus-hq
  naturalGas
  siteMeter
}
```

All meters define `siteMeter` (main) or `submeterOf` (submeter
referencing parent). Use `elecRef`, `naturalGasRef`, `chilledWaterRef`,
`hotWaterRef`, `steamRef` on loads to reference their upstream meter.

# Systems

Systems logically group equipment serving a common purpose.
Equipment references systems via `systemRef` (MultiRef).

```xeto
@hq-chw-sys: ChilledWaterSystem {
  navName: "Chilled Water System"
  disMacro: "$siteRef $navName"
  siteRef: @campus-hq
}

@hq-chiller1: Chiller {
  navName: "Chiller-1"
  disMacro: "$siteRef $navName"
  siteRef: @campus-hq
  systemRef: @hq-chw-sys
}
```

System types: `ChilledWaterSystem`, `HotWaterSystem`, `SteamSystem`,
`CondenserWaterSystem`, `ElecSystem`, `AirConditioningSystem`

# Ref Relationships

Key reference tags that link entities:

| Tag | Type | Links |
|-----|------|-------|
| `siteRef` | `Ref<of:Site>` | entity to its site |
| `spaceRef` | `Ref<of:Space>` | entity to its space |
| `equipRef` | `Ref<of:Equip>` | entity to parent equip |
| `systemRef` | `MultiRef<of:System>` | entity to systems |
| `airRef` | `MultiRef` | VAV/terminal to AHU |
| `elecRef` | `MultiRef` | load to electric meter |
| `hotWaterRef` | `MultiRef` | load to hot water source |
| `chilledWaterRef` | `MultiRef` | load to chilled water source |
| `submeterOf` | `Ref<of:Meter>` | submeter to parent meter |

# Full Example

A site with AHU, VAV, and points:

```xeto
@hq: Site {
  dis: "Headquarters"
  area: Number 50000ft²
  tz: "New_York"
  geoAddr: "100 Main St, Richmond VA"
}

@hq-floor1: Floor {
  navName: "Ground"
  disMacro: "$siteRef $navName"
  siteRef: @hq
  floorNum: 0
}

@hq-room101: Room {
  navName: "Room 101"
  disMacro: "$siteRef $navName"
  siteRef: @hq
  spaceRef: @hq-floor1
}

@hq-ahu1: Ahu {
  navName: "AHU-1"
  disMacro: "$siteRef $navName"
  siteRef: @hq
  elecRef: @hq-elec-hvac
  chilledWaterCooling
  hotWaterHeating
  vavZone
  singleDuct
  variableAirVolume
}

@hq-ahu1-dat: DischargeAirTempSensor {
  navName: "DischargeTemp"
  disMacro: "$equipRef $navName"
  siteRef: @hq
  equipRef: @hq-ahu1
}

@hq-ahu1-fan: DischargeFanSpeedModulatingCmd {
  navName: "Fan"
  disMacro: "$equipRef $navName"
  siteRef: @hq
  equipRef: @hq-ahu1
}

@hq-vav1: Vav {
  navName: "VAV-1A"
  disMacro: "$siteRef $navName"
  siteRef: @hq
  equipRef: @hq-ahu1
  airRef: @hq-ahu1
  spaceRef: @hq-room101
  hotWaterHeating
  singleDuct
  series
  pressureIndependent
}

@hq-vav1-zat: ZoneAirTempSensor {
  navName: "ZoneTemp"
  disMacro: "$equipRef $navName"
  siteRef: @hq
  equipRef: @hq-vav1
}

@hq-vav1-htg-sp: ZoneAirTempOccHeatingSp {
  navName: "HeatingSP"
  disMacro: "$equipRef $navName"
  siteRef: @hq
  equipRef: @hq-vav1
}

@hq-vav1-daf: DischargeAirFlowSensor {
  navName: "Flow"
  disMacro: "$equipRef $navName"
  siteRef: @hq
  equipRef: @hq-vav1
}

@hq-vav1-damper: DischargeDamperCmd {
  navName: "Damper"
  disMacro: "$equipRef $navName"
  siteRef: @hq
  equipRef: @hq-vav1
}

@hq-vav1-reheat: HotWaterValveCmd {
  navName: "Reheat"
  disMacro: "$equipRef $navName"
  siteRef: @hq
  equipRef: @hq-vav1
}

@hq-elec-main: AcElecMeter {
  navName: "ElecMeter-Main"
  disMacro: "$siteRef $navName"
  siteRef: @hq
  siteMeter
}

@hq-elec-hvac: AcElecMeter {
  navName: "ElecMeter-Hvac"
  disMacro: "$siteRef $navName"
  siteRef: @hq
  submeterOf: @hq-elec-main
}
```

# Xeto vs Haystack Fidelity

The examples in this document use xeto instance syntax for modeling.
When entities are stored in the folio database, they are flattened
to Haystack dicts. The `spec` tag identifies the type, and all
non-maybe marker slots from the spec are included automatically:

```xeto
// xeto instance - typed scalars and spec inheritance
@campus-hq: Site {
  dis: "Campus HQ"
  area: Number 55000ft²
  tz: TimeZone "New_York"
}
```

The above becomes a Haystack dict in folio. Typed scalars like `TimeZone`
become simple strings, and non-maybe markers from the spec hierarchy are
flattened as tags:

```
id: @campus-hq
spec: "ph::Site"
dis: "Campus HQ"
area: 55000ft²    // xeto number is haystack number
tz: "New_York"    // TimeZone scalar becomes string
site              // from Site spec
```

# Style Notes

- Sites and weather stations use `dis` directly; nested entities use `navName` + `disMacro`
- Equip `disMacro` is `"$siteRef $navName"`; point `disMacro` is `"$equipRef $navName"`
- Always set `siteRef` on systems, spaces, equips, and points
- Always set `equipRef` on points to their parent equipment
- Use `equipRef` to create equipment containment hierarchies
- Always set `spaceRef` on equip and points if known
- Use `systemRef` for cross-cutting logical groupings
- Use predefined point specs from `ph.points` when available
- Fall back to `NumberPoint`/`BoolPoint`/`EnumPoint` with markers if no spec exists
- Heating/cooling process markers go on the equipment, not points

