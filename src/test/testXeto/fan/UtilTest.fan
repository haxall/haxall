//
// Copyright (c) 2023, Brian Frank
// All Rights Reserved
//
// History:
//   1 Aug 2023  Brian Frank  Creation
//

using xeto
using xetoEnv
using haystack

**
** UtilTest
**
@Js
class UtilTest : Test
{

//////////////////////////////////////////////////////////////////////////
// NameUtils
//////////////////////////////////////////////////////////////////////////

  Void testNameUtils()
  {
    // dotted -> camel
    verifyEq(XetoUtil.dottedToCamel("x"), "x")
    verifyEq(XetoUtil.dottedToCamel("foo"), "foo")
    verifyEq(XetoUtil.dottedToCamel("x.y"), "xY")
    verifyEq(XetoUtil.dottedToCamel("foo.bar"), "fooBar")
    verifyEq(XetoUtil.dottedToCamel("foo.bar.baz"), "fooBarBaz")
    verifyEq(XetoUtil.dottedToCamel("foo.bar.baz."), "fooBarBaz")
    verifyEq(XetoUtil.dottedToCamel(".foo.bar.baz."), "FooBarBaz")
    verifyEq(XetoUtil.dottedToCamel("a.b.c.d"), "aBCD")
    verifyEq(XetoUtil.dottedToCamel("foo-bar-baz", '-'), "fooBarBaz")
    verifyEq(XetoUtil.dashedToCamel("foo-bar-baz"), "fooBarBaz")

    // camel -> dotted
    verifyEq(XetoUtil.camelToDotted("x"), "x")
    verifyEq(XetoUtil.camelToDotted("foo"), "foo")
    verifyEq(XetoUtil.camelToDotted("xY"), "x.y")
    verifyEq(XetoUtil.camelToDotted("fooBar"), "foo.bar")
    verifyEq(XetoUtil.camelToDotted("fooBarBaz"), "foo.bar.baz")
    verifyEq(XetoUtil.camelToDotted("aBCD"), "a.b.c.d")
    verifyEq(XetoUtil.camelToDotted("FooBar"), "foo.bar")
    verifyEq(XetoUtil.camelToDotted("FooBar", '-'), "foo-bar")
    verifyEq(XetoUtil.camelToDashed("FooBar"), "foo-bar")

    // qnameToName
    verifyEq(XetoUtil.qnameToName("foo::Bar"), "Bar")
    verifyEq(XetoUtil.qnameToName("foo.bar::Baz"), "Baz")
    verifyEq(XetoUtil.qnameToName("foo.bar::x"), "x")
    verifyEq(XetoUtil.qnameToName("foo.bar"), null)
    verifyEq(XetoUtil.qnameToName("foo.bar:"), null)
    verifyEq(XetoUtil.qnameToName("foo.bar::"), null)
    verifyEq(XetoUtil.qnameToName("foo.bar:Baz"), null)
    verifyEq(XetoUtil.qnameToName(":Y"), null)
    verifyEq(XetoUtil.qnameToName("::Y"), null)
    verifyEq(XetoUtil.qnameToName("x::Y"), "Y")

    // qnameToLib
    verifyEq(XetoUtil.qnameToLib("foo::Bar"), "foo")
    verifyEq(XetoUtil.qnameToLib("foo.bar::Baz"), "foo.bar")
    verifyEq(XetoUtil.qnameToLib("foo.bar::x"), "foo.bar")
    verifyEq(XetoUtil.qnameToLib("foo.bar"), null)
    verifyEq(XetoUtil.qnameToLib("foo.bar:"), null)
    verifyEq(XetoUtil.qnameToLib("foo.bar::"), null)
    verifyEq(XetoUtil.qnameToLib("foo.bar:Baz"), null)
    verifyEq(XetoUtil.qnameToLib(":Y"), null)
    verifyEq(XetoUtil.qnameToLib("::Y"), null)
    verifyEq(XetoUtil.qnameToLib("x::Y"), "x")
  }

//////////////////////////////////////////////////////////////////////////
// NameTable
//////////////////////////////////////////////////////////////////////////

  Void testNameTable()
  {
    t := NameTable();
    verifySame(t.typeof, NameTable#)
    start := 2
    verifyEq(t.size, start)
    verifyEq(t.size, 2)
    verifyEq(NameTable.initSize, 2)
    verifyEq(t.toCode(""), 1)
    verifyEq(t.toCode("id"), 2)
    verifyEq(t.toCode("foo"), 0)

    a := verifyAdd(t, "alpha", start+1)
    b := verifyAdd(t, "beta",  start+2)
    c := verifyAdd(t, "gamma", start+3)
    verifyEq(t.size, start+3)
    verifyEq(t.maxCode, start+3)

    names := Str:Int[:]
    /*
    Tags.tags.each |name|
    {
      code := verifyAdd(t, name)
      names[name] = code
    }
    */
    10_000.times |i|
    {
      name := Buf.random(8).toHex
      code := verifyAdd(t, name, start+4+i)
      names[name] = code
    }
    // t.dump(Env.cur.out)

    verifyEq(t.toCode("alpha"), a)
    verifyEq(t.toCode("beta"),  b)
    verifyEq(t.toCode("gamma"), c)
    names.each |code, name|
    {
      verifyEq(t.toCode(name), code)
      verifyEq(t.toName(code), name)
    }

    oldSize := t.size
    setCode := oldSize + 100_000

    // set
    verifyEq(t.isSparse, false)
    verifyEq(t.toCode("foo_bar"), 0)
    t.set(setCode, "foo_bar")
    verifyEq(t.isSparse, true)
    verifyEq(t.toCode("foo_bar"), setCode)
    verifyEq(t.size, oldSize+1)
    verifyEq(t.maxCode, oldSize+1)
    verifyEq(t.toCode("foo_bar"), setCode)

    // cannot use add once we have called set
    verifyErr(Err#) { t.add("foo_bar_2") }
    verifyEq(t.toCode("foo_bar_2"), 0)
    verifyEq(t.size, oldSize+1)
  }

  Int verifyAdd(NameTable t, Str name, Int expect)
  {
    oldSize := t.size
    verifyEq(t.toCode(name), 0)
    code := t.add(name)
    verifyEq(t.size, oldSize+1)
    verifyEq(code, expect)
    verifyEq(t.toName(code), name)
    verifyEq(t.toCode(name), code)
    verifyEq(t.add(name), code)
    return code
  }

//////////////////////////////////////////////////////////////////////////
// NameDict
//////////////////////////////////////////////////////////////////////////

  Void testNameDict()
  {
    t := NameTable()
    id := haystack::Ref.gen
    Spec? spec := null
    if (Env.cur.runtime != "js")
      spec = XetoEnv.cur.spec("ph::Site")

    verifyDict(t, 0, NameDict.empty,
      Str:Obj[:])

    verifyDict(t, 1, t.dict1("site", "marker"),
      Str:Obj["site":"marker"])

    verifyDict(t, 1, t.dict1("site", "marker"),
      Str:Obj["site":"marker"])

    verifyDict(t, 2, t.dict2("site", "marker", "dis", "Site"),
      Str:Obj["site":"marker", "dis":"Site"])

    verifyDict(t, 3, t.dict3("site", "marker", "dis", "Site", "int", 123),
      Str:Obj["site":"marker", "dis":"Site", "int":123])

    verifyDict(t, 4, t.dict4("site", "marker", "dis", "Site", "int", 123, "id", id),
      Str:Obj["site":"marker", "dis":"Site", "int":123, "id":id])

    verifyDict(t, 5, t.dict5("site", "marker", "dis", "Site", "int", 123, "dur", 10sec, "a", "A"),
      Str:Obj["site":"marker", "dis":"Site", "int":123, "dur":10sec, "a":"A"])

    verifyDict(t, 6, t.dict6("site", "marker", "dis", "Site", "int", 123, "dur", 10sec, "a", "A", "b", "B"),
      Str:Obj["site":"marker", "dis":"Site", "int":123, "dur":10sec, "a":"A", "b":"B"])

    verifyDict(t, 7, t.dict7("site", "marker", "dis", "Site", "int", 123, "dur", 10sec, "a", "A", "b", "B", "c", "C"),
      Str:Obj["site":"marker", "dis":"Site", "int":123, "dur":10sec, "a":"A", "b":"B", "c":"C"])

    verifyDict(t, 8, t.dict8("site", "marker", "dis", "Site", "int", 123, "dur", 10sec, "a", "A", "b", "B", "c", "C", "d", "D"),
      Str:Obj["site":"marker", "dis":"Site", "int":123, "dur":10sec, "a":"A", "b":"B", "c":"C", "d":"D"])

    verifyDict(t, 8, t.dict8("site", "marker", "dis", "Site", "int", 123, "dur", 10sec, "a", "A", "b", "B", "c", "C", "d", "D"),
      Str:Obj["site":"marker", "dis":"Site", "int":123, "dur":10sec, "a":"A", "b":"B", "c":"C", "d":"D"])

    verifyDict(t, -1, t.dictMap(Str:Obj["site":"marker", "dis":"Site", "int":123, "dur":10sec, "a":"A", "b":"B", "c":"C", "d":"D", "id":id]),
      Str:Obj["site":"marker", "dis":"Site", "int":123, "dur":10sec, "a":"A", "b":"B", "c":"C", "d":"D", "id":id])

    verifyDict(t, -1, t.dictMap(Str:Obj["site":"marker", "dis":"Site", "int":123, "dur":10sec, "a":"A", "b":"B", "c":"C", "d":"D", "id":id]),
      Str:Obj["site":"marker", "dis":"Site", "int":123, "dur":10sec, "a":"A", "b":"B", "c":"C", "d":"D", "id":id])

    big := Str:Obj[:]
    100.times |i| { big["n" + i] = "val " + i }
    verifyDict(t, -1, t.dictMap(big), big)
    verifyDict(t, -1, t.dictDict(Etc.makeDict(big)), big)

    verifyErr(NotImmutableErr#) { t.dict1("a", this) }
    verifyErr(NotImmutableErr#) { t.dict2("a", "x", "b", this) }
    verifyErr(NotImmutableErr#) { t.dict3("a", "x", "b", "x", "c", this) }
    verifyErr(NotImmutableErr#) { t.dict4("a", "x", "b", "x", "c", "x", "d", this) }
    verifyErr(NotImmutableErr#) { t.dict5("a", "x", "b", "x", "c", "x", "d", "x", "e", this) }
    verifyErr(NotImmutableErr#) { t.dict6("a", "x", "b", "x", "c", "x", "d", "x", "e", "x", "f", this) }
    verifyErr(NotImmutableErr#) { t.dict7("a", "x", "b", "x", "c", "x", "d", "x", "e", "x", "f", "x", "g", this) }
    verifyErr(NotImmutableErr#) { t.dict8("a", "x", "b", "x", "c", "x", "d", "x", "e", "x", "f", "x", "g", "x", "h", this) }
    verifyErr(NotImmutableErr#) { t.dictMap(["a":this]) }
    verifyErr(NotImmutableErr#) { t.dictMap(big.dup.set("foo", this)) }
    verifyErr(NotImmutableErr#) { t.dict1("foo", "bar").map |v, n| { this } }
    verifyErr(NotImmutableErr#) { t.dictMap(big).map |v, n| { this } }
  }

  Void verifyDict(NameTable t, Int fixed, NameDict d, Str:Obj expect)
  {
    // size
    verifyEq(d.isEmpty, d.size == 0)
    verifyEq(d.size, expect.size)
    verifyEq(d.fixedSize, fixed)

    // construct back from map
    x := t.dictMap(expect)
    verifyEq(x.fixedSize, fixed)

    // id
    if (expect["id"] != null)
    {
      verifySame(d.id, expect["id"])
    }
    else
    {
      verifyErr(UnresolvedErr#) { d.id }
    }

    // get, getByCode, has, missing, trap
    key := null
    expect.each |v, n|
    {
      verifyEq(d.get(n), v)
      verifyEq(x.get(n), v)
      verifyEq(d.get(n, "bad"), v)
      verifyEq(d.has(n), true)
      verifyEq(d.missing(n), false)
      verifyEq(d.trap(n), v)
      verifyEq(t.toCode(n) > 0, true)
      verifyEq(v, d.getByCode(t.toCode(n)))
      key = n
    }

    // nameAt/valAt
    i := 0
    d.each |v, n|
    {
      verifyEq(d.nameAt(i), t.toCode(n))
      verifyEq(d.valAt(i), v)
      i++
    }

    // each
    acc := Str:Obj[:]
    d.each |v, n|
    {
      acc[n] = v
      key = n
    }
    verifyEq(acc, expect)

    // eachWhile
    if (key != null)
    {
      expectWhile := expect.dup { remove(key) }
      acc.clear
      r := d.eachWhile |v, n|
      {
        if (n == key) return "break"
        acc[n] = v
        return null
      }
      verifyEq(r, "break")
      verifyEq(acc, expectWhile)
    }

    // missing
    verifyEq(d.get("bad"), null)
    verifyEq(d.get("bad", "def"), "def")
    verifyEq(d.has("bad"), false)
    verifyEq(d.missing("bad"), true)

    // make from dict
    verifySame(t.dictDict(d), d)
    x = t.dictDict(Etc.makeDict(expect))

    // readDict
    names := Int[,]
    vals := Obj[,]
    d.each |v, n|
    {
      names.add(t.toCode(n))
      vals.add(v)
    }
    x = t.readDict(d.size, TestNameDictReader(names, vals))
    verifyEq(x.size, d.size)
    verifyEq(x.fixedSize, fixed)
    x.each |v, n| { verifyEq(d.get(n), v) }

    // map
    x = d.map |v, n| { n.upper }
    verifyEq(x.size, d.size)
    verifyEq(x.fixedSize, fixed)
    x.each |v, n| { verifyEq(v, n.upper) }
  }

//////////////////////////////////////////////////////////////////////////
// Tags
//////////////////////////////////////////////////////////////////////////

  /*
  static Str[] tags()
  {
    s :=
     """absorption
        ac
        ac-elec
        ac-elec-meter
        ac-freq
        accumulate
        active
        active-energy
        active-power
        actuator
        ahu
        ahuZoneDelivery
        air
        air-conditioning-system
        air-exhaust-system
        air-input
        air-output
        air-system
        air-temp
        air-velocity
        air-ventilation-system
        airCooling
        airHandlingEquip
        airQuality
        airQualityZonePoints
        airRef
        airTerminalUnit
        airVolumeAdjustability
        alarm
        angle
        apparent
        apparent-energy
        apparent-power
        area
        assembly
        association
        ates
        atesClosedLoop
        atesDesign
        atesDoublet
        atesDoubletPaired
        atesMono
        atesUnidirectional
        atmospheric
        atmospheric-pressure
        avg
        bacnet
        barometric
        baseUri
        battery
        biomass
        biomassHeating
        blowdown
        blowdown-water
        blowdown-water-input
        blowdown-water-output
        blowdownWaterRef
        bluetooth
        boiler
        bool
        branchSelector
        bypass
        cable
        cav
        centrifugal
        ch2o
        ch2o-concentration
        ch4
        ch4-emission
        children
        childrenFlatten
        chilled
        chilled-water
        chilled-water-input
        chilled-water-output
        chilled-water-plant
        chilled-water-system
        chilledBeam
        chilledBeamZone
        chilledWaterCooling
        chilledWaterRef
        chiller
        chiller-absorption
        chiller-centrifugal
        chiller-reciprocal
        chiller-rotaryScrew
        chillerMechanism
        choice
        circ
        circuit
        cloudage
        cmd
        co
        co-concentration
        co2
        co2-concentration
        co2-emission
        co2e
        coal
        coalHeating
        coap
        coil
        cold
        cold-water
        coldDeck
        compressor
        computed
        computer
        concentration
        condensate
        condensate-input
        condensate-output
        condensateRef
        condenser
        condenser-water
        condenser-water-input
        condenser-water-output
        condenser-water-system
        condenserClosedLoop
        condenserCooling
        condenserLoop
        condenserOpenLoop
        condenserWaterRef
        conditioning
        conduit
        constantAirVolume
        containedBy
        contains
        controller
        controls
        controls-panel
        cool
        cool-water
        cooling
        coolingCapacity
        coolingCoil
        coolingOnly
        coolingProcess
        coolingTower
        coord
        crac
        cur
        cur-point
        curErr
        curStatus
        curVal
        current
        current-angle
        current-imbalance
        current-magnitude
        current-thd
        dali
        damper
        damper-actuator
        dataCenter
        date
        dateTime
        daytime
        dc
        dc-elec
        dc-elec-meter
        deadband
        def
        defx
        delta
        demand
        depends
        deprecated
        design
        dessicantDehumidifier
        device
        deviceRef
        dewPoint
        dict
        diesel
        directZone
        direction
        dis
        discharge
        diverting
        doas
        doc
        docAssociations
        docTaxonomy
        domestic
        domestic-cold-water-system
        domestic-hot-water-system
        domestic-water
        domestic-water-input
        domestic-water-output
        domestic-water-system
        domesticWaterRef
        dualDuct
        duct
        ductArea
        ductConfig
        ductDeck
        ductSection
        duration
        dxCooling
        dxHeating
        economizer
        economizing
        effective
        efficiency
        elec
        elec-current
        elec-demand
        elec-energy
        elec-input
        elec-meter
        elec-output
        elec-panel
        elec-power
        elec-system
        elec-volt
        elecHeating
        elecRef
        elevator
        emission
        enable
        energy
        entering
        enthalpy
        entity
        enum
        equip
        equipRef
        escalator
        evaporator
        evse
        evse-assembly
        evse-cable
        evse-equip
        evse-port
        evse-system
        exhaust
        export
        extraction
        faceBypass
        fan
        fan-motor
        fanPowered
        fcu
        feature
        feelsLike
        fileExt
        filetype
        filetype:csv
        filetype:json
        filetype:jsonld
        filetype:trio
        filetype:turtle
        filetype:zinc
        filter
        filterStr
        floor
        floorNum
        flow
        flow-meter
        flowInverter
        flue
        fluid
        flux
        freezeStat
        freq
        ftp
        fuelOil
        fuelOil-input
        fuelOil-output
        fuelOilHeating
        fuelOilRef
        fumeHood
        gas
        gasoline
        gasoline-input
        gasoline-output
        gasolineRef
        geoAddr
        geoCity
        geoCoord
        geoCountry
        geoCounty
        geoElevation
        geoPlace
        geoPostalCode
        geoState
        geoStreet
        grid
        ground
        ground-floor
        ground-water
        haystack
        header
        heat
        heatExchanger
        heatPump
        heatRecovery
        heatWheel
        heating
        heatingCoil
        heatingOnly
        heatingProcess
        hfc
        hfc-emission
        his
        his-point
        hisErr
        hisMode
        hisStatus
        hisTotalized
        hot
        hot-water
        hot-water-boiler
        hot-water-input
        hot-water-output
        hot-water-plant
        hot-water-system
        hotDeck
        hotWaterHeating
        hotWaterRef
        http
        humidifier
        humidifier-equip
        humidity
        hvac
        hvac-zone-space
        hvacMode
        hvacZonePoints
        ice
        id
        illuminance
        imap
        imbalance
        import
        indoorUnit
        infiltration
        inlet
        input
        inputs
        int
        intensity
        irradiance
        is
        isolation
        kind
        knx
        laptop
        leaving
        level
        lib
        lib:ph
        lib:phIct
        lib:phIoT
        lib:phScience
        light
        light-level
        lighting
        lighting-system
        lighting-zone-space
        lightingZonePoints
        liquid
        list
        load
        luminaire
        luminance
        luminous
        luminous-flux
        luminous-intensity
        magnitude
        makeup
        makeup-water
        makeup-water-input
        makeup-water-output
        makeupWaterRef
        mandatory
        marker
        mau
        max
        maxVal
        mech
        meter
        meterScope
        mime
        min
        minVal
        mixed
        mixing
        mobile
        mobile-phone
        modbus
        motor
        movingWalkway
        mqtt
        multiZone
        n2o
        n2o-emission
        na
        naturalGas
        naturalGas-input
        naturalGas-output
        naturalGasHeating
        naturalGasRef
        net
        network
        networkRef
        networking
        networking-device
        networking-router
        networking-switch
        neutralDeck
        nf3
        nf3-emission
        nh3
        nh3-concentration
        no2
        no2-concentration
        noSideEffects
        nodoc
        nosrc
        notInherited
        number
        o2
        o3
        o3-concentration
        obix
        occ
        occupancy
        occupants
        occupied
        of
        op
        op:about
        op:close
        op:defs
        op:filetypes
        op:hisRead
        op:hisWrite
        op:invokeAction
        op:libs
        op:nav
        op:ops
        op:pointWrite
        op:read
        op:watchPoll
        op:watchSub
        op:watchUnsub
        openEnum
        outdoorUnit
        output
        outputs
        outside
        panel
        parallel
        perimeterHeat
        pf
        pfc
        pfc-emission
        phase
        phaseCount
        phenomenon
        phone
        pipe
        pipeFluid
        pipeSection
        plant
        plantLoop
        pm01
        pm01-concentration
        pm10
        pm10-concentration
        pm25
        pm25-concentration
        point
        pointFunction
        pointGroup
        pointQuantity
        pointSubject
        pop3
        port
        power
        precipitation
        prefUnit
        pressure
        pressureDependent
        pressureIndependent
        primaryFunction
        primaryLoop
        process
        propane
        propaneHeating
        protocol
        pump
        pump-motor
        purge
        purge-water
        quality
        quantities
        quantity
        quantityOf
        rack
        radiantEquip
        radiantFloor
        radiator
        rated
        reactive
        reactive-energy
        reactive-power
        reciprocal
        reciprocalOf
        ref
        refrig
        refrig-input
        refrig-output
        refrig-system
        refrigRef
        reheat
        relationship
        remove
        return
        roof
        roof-floor
        room
        rotaryScrew
        router
        rtu
        run
        scalar
        secondaryLoop
        sensor
        series
        server
        server-computer
        serviceFactor
        sf6
        sf6-emission
        singleDuct
        singlePhase
        site
        siteMeter
        siteRef
        smtp
        snmp
        solar
        solar-irradiance
        solid
        sox
        sp
        space
        spaceRef
        span
        speed
        stage
        standby
        steam
        steam-boiler
        steam-input
        steam-output
        steam-plant
        steam-system
        steamHeating
        steamRef
        str
        submeter
        submeterOf
        substance
        subterranean
        subterranean-floor
        switch
        symbol
        system
        systemRef
        tablet
        tagOn
        tags
        tank
        tankSubstance
        temp
        tertiaryLoop
        thd
        thermal
        thermostat
        threePhase
        time
        total
        transient
        transitive
        tripleDuct
        tvoc
        tvoc-concentration
        tz
        unit
        unitVent
        unocc
        ups
        uri
        val
        valve
        valve-actuator
        variableAirVolume
        vav
        vav-parallel
        vav-series
        vavAirCircuit
        vavModulation
        vavZone
        velocity
        ventilation
        version
        verticalTransport
        vfd
        vfd-freq
        vfd-speed
        visibility
        volt
        volt-angle
        volt-imbalance
        volt-magnitude
        volume
        vrf
        vrf-coolingOnly-system
        vrf-equip
        vrf-heatPump-system
        vrf-heatRecovery-system
        vrf-indoorUnit
        vrf-indoorUnit-fcu
        vrf-outdoorUnit
        vrf-refrig-plant
        vrf-system
        warm
        warm-water
        water
        water-system
        waterCooling
        weather
        weather-point
        weatherCond
        weatherStation
        weatherStationRef
        well
        wetBulb
        wikipedia
        wind
        wind-direction
        wind-speed
        wire
        writable
        writable-point
        writeErr
        writeLevel
        writeStatus
        writeVal
        xstr
        yearBuilt
        zigbee
        zone
        zone-space
        zwave"""
    return s.splitLines
  }
  */
}

**************************************************************************
** TestNameDictReader
**************************************************************************

@Js
internal class TestNameDictReader : NameDictReader
{
  new make(Int[] names, Obj[] vals)
  {
    this.names = names
    this.vals = vals
  }

  override Int readName() { names[i] }

  override Obj? readVal() { vals[i++] }

  Int[] names
  Obj[] vals
  Int i
}