//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Aug 2026  Creation
//

using util
using xeto
using xetom
using haystack

**
** RdfExportTest
**
class RdfExportTest : AbstractXetoTest
{
  Void testEffectiveInheritanceAndMarkers()
  {
    rdf := export(
      Str<|Person : Dict <doc:"A person"> {
               dis: Str <doc:"Display name">
               active
               temporary: Marker?
             }

             Employee : Person|>)

    // Employee receives effective validation constraints, but vocabulary
    // resources and documentation remain owned by their declarations.
    verify(rdf.contains("temp:Employee\n  a sys:Class ;\n  a rdfs:Class ;\n  a sh:NodeShape ;"))
    verify(rdf.contains("sh:targetClass temp:Employee ;"))
    verify(rdf.contains("sh:path temp:Person.dis ;"))
    verifyEq(countMatches(rdf, "sys:hasMarker temp:Person.active ;"), 2)
    verifyEq(countMatches(rdf, "sys:hasMarker temp:Person.temporary ;"), 2)
    verifyEq(countMatches(rdf, "sh:hasValue temp:Person.active ;"), 2)
    verifyEq(countMatches(rdf, "sh:hasValue temp:Person.temporary ;"), 0)
    verifyEq(countMatches(rdf, "rdfs:comment \"A person\"@en ;"), 1)
    verifyEq(countMatches(rdf, "temp:Person.dis\n  a rdf:Property ;"), 1)
  }

  Void testScalarConstraints()
  {
    rdf := export(
      Str<|Code : Scalar <pattern:"[A-Z]{2}">

             Reading : Dict {
               label: Str <nonEmpty, minSize:2, maxSize:40>
               count: Int <minVal:1, maxVal:60>
               value: Number
               enabled: Bool
               commissioned: Date
               code: Code
               fixed: Str <invariant> "ok"
               optional: Str?
             }|>)

    verify(rdf.contains("sh:path temp:Reading.label ;\n    sh:datatype xsd:string ;"))
    verify(rdf.contains("sh:minLength 2 ;"))
    verify(rdf.contains("sh:maxLength 40 ;"))
    verify(rdf.contains("sh:pattern \"\\\\S\" ;"))

    verify(rdf.contains("sh:path temp:Reading.count ;\n    sh:datatype xsd:integer ;"))
    verify(rdf.contains("sh:minInclusive 1 ;"))
    verify(rdf.contains("sh:maxInclusive 60 ;"))
    verify(rdf.contains("sh:path temp:Reading.value ;\n    sh:datatype xsd:decimal ;"))
    verify(rdf.contains("sh:path temp:Reading.enabled ;\n    sh:datatype xsd:boolean ;"))
    verify(rdf.contains("sh:path temp:Reading.commissioned ;\n    sh:datatype xsd:date ;"))
    verify(rdf.contains("sh:path temp:Reading.code ;\n    sh:datatype xsd:string ;"))
    verify(rdf.contains("sh:pattern \"[A-Z]{2}\" ;"))
    verify(rdf.contains("sh:hasValue \"ok\"^^xsd:string ;"))

    // A custom scalar without direct validation constraints is vocabulary,
    // not an empty SHACL shape.
    code := rdf[rdf.index("temp:Code\n")..<rdf.index("temp:Reading\n")]
    verifyFalse(code.contains("a sh:NodeShape"))
  }

  Void testExtendedScalarConstraints()
  {
    rdf := export(
      Str<|Reading : Dict {
               decimal: Number <minVal:1.5, maxVal:2.5>
               observedAt: Time
               timestamp: DateTime
               source: Uri
               zone: TimeZone
               patterned: Str <pattern:"\\d{2}">
               optional: Str?
               fixedCount: Int <invariant> 7
               fixedEnabled: Bool <invariant> "true"
               fixedDate: Date <invariant> "2026-08-10"
               defaulted: Str "fallback"
             }|>)

    decimal := propertyShape(rdf, "Reading.decimal")
    verify(decimal.contains("sh:datatype xsd:decimal ;"))
    verify(decimal.contains("sh:minInclusive 1.5 ;"))
    verify(decimal.contains("sh:maxInclusive 2.5 ;"))

    verify(propertyShape(rdf, "Reading.observedAt").contains("sh:datatype xsd:time ;"))
    verify(propertyShape(rdf, "Reading.timestamp").contains("sh:datatype xsd:dateTime ;"))
    verify(propertyShape(rdf, "Reading.source").contains("sh:datatype xsd:anyURI ;"))
    zone := propertyShape(rdf, "Reading.zone")
    verify(zone.contains("sh:datatype xsd:string ;"), zone)

    patterned := propertyShape(rdf, "Reading.patterned")
    verify(patterned.contains("sh:pattern \"\\\\d{2}\" ;"))

    optional := propertyShape(rdf, "Reading.optional")
    verifyFalse(optional.contains("sh:minCount"))
    verify(optional.contains("sh:maxCount 1 ;"))

    verify(propertyShape(rdf, "Reading.fixedCount")
      .contains("sh:hasValue \"7\"^^xsd:integer ;"))
    verify(propertyShape(rdf, "Reading.fixedEnabled")
      .contains("sh:hasValue \"true\"^^xsd:boolean ;"))
    verify(propertyShape(rdf, "Reading.fixedDate")
      .contains("sh:hasValue \"2026-08-10\"^^xsd:date ;"))
    verifyFalse(propertyShape(rdf, "Reading.defaulted").contains("sh:hasValue"))

    // Built-in scalar patterns describe Xeto source syntax, not RDF values.
    verifyEq(countMatches(rdf, "sh:pattern "), 1)
  }

  Void testDeterministicOutput()
  {
    src := Str<|Reading : Dict {
                 label: Str <nonEmpty, minSize:2>
                 count: Int <minVal:1>
                }|>
    verifyEq(export(src), export(src))
  }

  Void testUnsupportedSystemScalarFailsClosed()
  {
    verifyErrMsg(UnsupportedErr#, "RDF scalar datatype not supported: sys::Version")
    {
      export(Str<|Reading : Dict { version: Version }|>)
    }
  }

  Void testStructuredValueShapes()
  {
    rdf := export(
      Str<|Suit : Enum {
               clubs    <key:"Clubs">
               diamonds <key:"Diamonds">
             }

             Site : Dict
             Related : Dict
             Address : Dict { city: Str }

             Equip : Dict {
               suit: Suit
               siteRef: Ref<of:Site>
               related: MultiRef?<of:Related>
               address: Address
             }|>)

    suit := propertyShape(rdf, "Equip.suit")
    verify(suit.contains("sh:datatype xsd:string ;"), suit)
    verify(suit.contains("sh:in (\"Clubs\"^^xsd:string \"Diamonds\"^^xsd:string) ;"), suit)
    verifyFalse(rdf.contains("temp:Suit.clubs"), rdf)
    suitClass := resourceBlock(rdf, "temp:Suit")
    verifyFalse(suitClass.contains("a sh:NodeShape"), suitClass)

    siteRef := propertyShape(rdf, "Equip.siteRef")
    verify(siteRef.contains("sh:nodeKind sh:IRI ;"), siteRef)
    verify(siteRef.contains("sh:class temp:Site ;"), siteRef)
    verify(siteRef.contains("sh:minCount 1 ;"), siteRef)
    verify(siteRef.contains("sh:maxCount 1 ;"), siteRef)

    related := propertyShape(rdf, "Equip.related")
    verify(related.contains("sh:nodeKind sh:IRI ;"), related)
    verify(related.contains("sh:class temp:Related ;"), related)
    verifyFalse(related.contains("sh:minCount"), related)
    verifyFalse(related.contains("sh:maxCount"), related)

    address := propertyShape(rdf, "Equip.address")
    verify(address.contains("sh:node temp:Address ;"), address)
    verify(address.contains("sh:minCount 1 ;"), address)
    verify(address.contains("sh:maxCount 1 ;"), address)
  }

  Void testStructuredInstances()
  {
    rdf := export(
      Str<|Suit : Enum { clubs <key:"Clubs"> }

             Site : Dict
             Related : Dict
             Address : Dict { city: Str }

             Equip : Dict {
               dis: Str
               count: Int
               enabled: Bool
               commissioned: Date
               suit: Suit
               siteRef: Ref<of:Site>
               related: MultiRef?<of:Related>
               address: Address
               equip
             }

             Person : Dict { address: Address }

             @site1: Site {}
             @related1: Related {}
             @related2: Related {}

             @equip1: Equip {
               dis: "AHU-1"
               count: 7
               enabled: "true"
               commissioned: 2026-08-11
               suit: "Clubs"
               siteRef: @site1
               related: MultiRef { @related1, @related2 }
               address: Address { city: "Richmond" }
               nickname: "Air handler"
               imported
             }

             @person1: Person {
               address @address1: Address { city: "Norfolk" }
             }|>)

    equip := instanceBlock(rdf, "equip1")
    verify(equip.contains("a sys:Entity, temp:Equip ;"), equip)
    verify(equip.contains("temp:Equip.dis \"AHU-1\"^^xsd:string ;"), equip)
    verify(equip.contains("temp:Equip.count \"7\"^^xsd:integer ;"), equip)
    verify(equip.contains("temp:Equip.enabled \"true\"^^xsd:boolean ;"), equip)
    verify(equip.contains("temp:Equip.commissioned \"2026-08-11\"^^xsd:date ;"), equip)
    verify(equip.contains("temp:Equip.suit \"Clubs\"^^xsd:string ;"), equip)
    verify(equip.contains("temp:Equip.siteRef temp:site1 ;"), equip)
    verifyEq(countMatches(equip, "temp:Equip.related "), 2)
    verify(equip.contains("sys:hasMarker temp:Equip.equip ;"), equip)
    verify(equip.contains("temp:Equip.address [\n    a temp:Address ;"), equip)
    verify(equip.contains("temp:Address.city \"Richmond\"^^xsd:string ;"), equip)
    verify(equip.contains("temp:Equip.nickname \"Air handler\"^^xsd:string ;"), equip)
    verify(equip.contains("sys:hasMarker temp:Equip.imported ;"), equip)
    verifyFalse(equip.contains("rdfs:label"), equip)

    person := instanceBlock(rdf, "person1")
    verify(person.contains("temp:Person.address temp:address1 ;"), person)
    address := instanceBlock(rdf, "address1")
    verify(address.contains("a sys:Entity, temp:Address ;"), address)
    verify(address.contains("temp:Address.city \"Norfolk\"^^xsd:string ;"), address)
  }

  Void testChoiceShapesAndInstances()
  {
    rdf := export(
      Str<|HeatingProcess : Choice
             HotWaterHeating : HeatingProcess { hotWaterHeating }
             SteamHeating : HeatingProcess { steamHeating }

             RequiredEquip : Dict { heatingProcess: HeatingProcess }
             OptionalEquip : Dict { heatingProcess: HeatingProcess? }
             MultiEquip : Dict { heatingProcesses: HeatingProcess <multiChoice> }
             OptionalMultiEquip : Dict { heatingProcesses: HeatingProcess? <multiChoice> }

             @equip1: MultiEquip {
               hotWaterHeating
               steamHeating
             }|>)

    hotWater := resourceBlock(rdf, "temp:HotWaterHeating")
    verify(hotWater.contains("rdfs:subClassOf temp:HeatingProcess ;"), hotWater)
    verify(hotWater.contains("sys:hasMarker temp:HotWaterHeating.hotWaterHeating ;"), hotWater)
    verify(rdf.contains("temp:HotWaterHeating.hotWaterHeating\n  a sys:Marker ;"), rdf)

    required := propertyShape(rdf, "RequiredEquip.heatingProcess")
    verify(required.contains("sh:in (temp:HotWaterHeating temp:SteamHeating) ;"), required)
    verify(required.contains("sh:minCount 1 ;"), required)
    verify(required.contains("sh:maxCount 1 ;"), required)

    optional := propertyShape(rdf, "OptionalEquip.heatingProcess")
    verifyFalse(optional.contains("sh:minCount"), optional)
    verify(optional.contains("sh:maxCount 1 ;"), optional)

    multi := propertyShape(rdf, "MultiEquip.heatingProcesses")
    verify(multi.contains("sh:minCount 1 ;"), multi)
    verifyFalse(multi.contains("sh:maxCount"), multi)

    optionalMulti := propertyShape(rdf, "OptionalMultiEquip.heatingProcesses")
    verifyFalse(optionalMulti.contains("sh:minCount"), optionalMulti)
    verifyFalse(optionalMulti.contains("sh:maxCount"), optionalMulti)

    equip := instanceBlock(rdf, "equip1")
    verify(equip.contains("temp:MultiEquip.heatingProcesses temp:HotWaterHeating ;"), equip)
    verify(equip.contains("temp:MultiEquip.heatingProcesses temp:SteamHeating ;"), equip)
    verifyFalse(equip.contains("sys:hasMarker"), equip)
  }

  Void testListShapesAndInstances()
  {
    rdf := export(
      Str<|Address : Dict { city: Str }

             Batch : Dict {
               names: List <of:Str, minSize:2, maxSize:3>
               numbers: List <of:Number, nonEmpty>
               addresses: List <of:Address>
             }

             @batch1: Batch {
               names: {"alpha", "beta"}
               numbers: {1, 2.5}
               addresses: {
                 Address { city: "Richmond" },
                 Address { city: "Norfolk" }
               }
             }|>)

    names := propertyShape(rdf, "Batch.names")
    verify(names.contains("sh:path ( [ sh:zeroOrMorePath rdf:rest ] rdf:first ) ;"), names)
    verify(names.contains("sh:datatype xsd:string ;"), names)
    verify(names.contains("sh:minCount 2 ;"), names)
    verify(names.contains("sh:maxCount 3 ;"), names)

    numbers := propertyShape(rdf, "Batch.numbers")
    verify(numbers.contains("sh:datatype xsd:decimal ;"), numbers)
    verify(numbers.contains("sh:minCount 1 ;"), numbers)

    addresses := propertyShape(rdf, "Batch.addresses")
    verify(addresses.contains("sh:class temp:Address ;"), addresses)

    batch := instanceBlock(rdf, "batch1")
    alpha := batch.index("\"alpha\"^^xsd:string")
    beta  := batch.index("\"beta\"^^xsd:string")
    verify(alpha != null && beta != null && alpha < beta, batch)
    verify(batch.contains("\"1\"^^xsd:decimal"), batch)
    verify(batch.contains("\"2.5\"^^xsd:decimal"), batch)
    richmond := batch.index("\"Richmond\"^^xsd:string")
    norfolk  := batch.index("\"Norfolk\"^^xsd:string")
    verify(richmond != null && norfolk != null && richmond < norfolk, batch)
  }

  Void testUnsupportedListItemTypesFailClosed()
  {
    try
    {
      export(Str<|Color : Enum { red }
                   Foo : Dict { colors: List <of:Color> }|>)
      fail("Expected unsupported enum list item")
    }
    catch (UnsupportedErr err)
    {
      verify(err.msg.contains("Foo.colors: enum item type"), err.msg)
      verify(err.msg.endsWith("::Color"), err.msg)
    }

    try
    {
      export(Str<|Foo : Dict { refs: List <of:Ref> }|>)
      fail("Expected unsupported reference list item")
    }
    catch (UnsupportedErr err)
    {
      verify(err.msg.contains("Foo.refs: reference item type sys::Ref"), err.msg)
    }
  }

  Void testQudtMappingValidation()
  {
    mappings := RdfQudtMappings(
      "fahrenheit=DEG_F\nus_dollar=USD\n",
      "temperature=Temperature\ncurrency=Currency\n")
    verifyEq(mappings.unitCount, 2)
    verifyEq(mappings.quantityCount, 2)
    verifyEq(mappings.unit(Unit.fromStr("°F")), "unit:DEG_F")
    verifyEq(mappings.unit(Unit.fromStr("\$")), "currency:USD")
    verifyEq(mappings.quantity(UnitQuantity.temperature), ["Temperature"])

    verifyErrMsg(IOErr#, "qudt-units.props: mapping resource is empty")
    {
      ignored := RdfQudtMappings("", "temperature=Temperature\n")
    }
    verifyErrMsg(IOErr#, "qudt-quantities.props: mapping resource is empty")
    {
      ignored := RdfQudtMappings("fahrenheit=DEG_F\n", "")
    }

    verifyErrMsg(IOErr#, "qudt-units.props:2: duplicate mapping 'fahrenheit'; first declared on line 1")
    {
      ignored := RdfQudtMappings("fahrenheit=DEG_F\nfahrenheit=DEG_C\n", "temperature=Temperature\n")
    }
    verifyErrMsg(IOErr#, "qudt-units.props:1: expected one non-empty name=value row")
    {
      ignored := RdfQudtMappings("fahrenheit DEG_F\n", "temperature=Temperature\n")
    }
    verifyErrMsg(IOErr#, "qudt-units.props: unknown canonical Xeto unit '°F'")
    {
      ignored := RdfQudtMappings("°F=DEG_F\n", "temperature=Temperature\n")
    }
    verifyErrMsg(IOErr#, "qudt-quantities.props: empty QUDT target for 'temperature'")
    {
      ignored := RdfQudtMappings("fahrenheit=DEG_F\n", "temperature=Temperature,\n")
    }
    verifyErrMsg(IOErr#, "qudt-quantities.props: duplicate QUDT target 'Temperature' for 'temperature'")
    {
      ignored := RdfQudtMappings("fahrenheit=DEG_F\n", "temperature=Temperature,Temperature\n")
    }

    ns := createNamespace(["sys"])
    lib := ns.compileTempLib("Foo : Dict {}")
    verifyErrMsg(ArgErr#, "qudtMappings option must be RdfQudtMappings, not sys::Str")
    {
      RdfExporter(ns, Buf().out, Etc.makeDict(["qudtMappings":"invalid"])).start.lib(lib).end
    }
  }

  Void testUnitAndQuantityShapesAndInstances()
  {
    mappings := RdfQudtMappings(
      "fahrenheit=DEG_F\npercent=PERCENT\nkilowatt=KiloW\nus_dollar=USD\n",
      "temperature=Temperature\npower=Power\ncurrency=Currency\n")
    rdf := exportWithMappings(
      Str<|Reading : Dict {
               unit: Unit <quantity:"temperature">
               percent: Number <unit:"%", minVal:0, maxVal:100>
               power: Number <quantity:"power">
               currency: Unit <quantity:"currency">
             }

             @reading1: Reading {
               unit: Unit "°F"
               percent: Number "50%"
               power: Number "1kW"
               currency: Unit "\$"
             }|>, mappings)

    verify(rdf.contains("sh:path temp:Reading.unit ;\n    sh:class qudt:Unit ;"), rdf)
    verify(rdf.contains("sh:hasValue quantitykind:Temperature"), rdf)
    verify(rdf.contains("sh:path temp:Reading.percent ;\n    sh:minCount 1 ;"), rdf)
    verify(rdf.contains("sh:class qudt:QuantityValue ;"), rdf)
    verify(rdf.contains("sh:path qudt:numericValue ;"), rdf)
    verify(rdf.contains("sh:minInclusive 0 ;"), rdf)
    verify(rdf.contains("sh:maxInclusive 100 ;"), rdf)
    verify(rdf.contains("sh:path qudt:unit ;"), rdf)
    verify(rdf.contains("sh:hasValue unit:PERCENT ;"), rdf)
    verify(rdf.contains("sh:hasValue quantitykind:Power"), rdf)

    reading := instanceBlock(rdf, "reading1")
    verify(reading.contains("temp:Reading.unit unit:DEG_F ;"), reading)
    verify(reading.contains("qudt:numericValue \"50\"^^xsd:decimal ;"), reading)
    verify(reading.contains("qudt:unit unit:PERCENT"), reading)
    verify(reading.contains("qudt:numericValue \"1\"^^xsd:decimal ;"), reading)
    verify(reading.contains("qudt:unit unit:KiloW"), reading)
    verify(reading.contains("temp:Reading.currency currency:USD ;"), reading)

    // QUDT ontology facts are external validation inputs, not copied output.
    verifyFalse(rdf.contains("unit:DEG_F a qudt:Unit"), rdf)
    verifyFalse(rdf.contains("quantitykind:Temperature skos:broader"), rdf)
  }

  Void testUnmappedUnitFailsClosed()
  {
    mappings := RdfQudtMappings("percent=PERCENT\n", "temperature=Temperature\n")
    verifyErrMsg(UnsupportedErr#, "No reviewed QUDT mapping for Xeto unit 'fahrenheit'")
    {
      exportWithMappings(
        Str<|Reading : Dict { unit: Unit }
               @reading1: Reading { unit: Unit "°F" }|>, mappings)
    }
  }

  private Str export(Str src)
  {
    ns  := createNamespace(["sys"])
    lib := ns.compileTempLib(src)
    buf := Buf()
    RdfExporter(ns, buf.out, Etc.dict0).start.lib(lib).end
    return buf.flip.readAllStr.replace(lib.name, "temp")
  }

  private Str exportWithMappings(Str src, RdfQudtMappings mappings)
  {
    ns  := createNamespace(["sys"])
    lib := ns.compileTempLib(src)
    buf := Buf()
    opts := Etc.makeDict(["qudtMappings":mappings])
    RdfExporter(ns, buf.out, opts).start.lib(lib).end
    return buf.flip.readAllStr.replace(lib.name, "temp")
  }

  private Str propertyShape(Str rdf, Str property)
  {
    path := "sh:path temp:${property} ;"
    start := rdf.index(path)
    if (start == null) throw Err("Missing property shape for ${property}")
    close := "  ] ;"
    end := rdf.index(close, start)
    if (end == null) throw Err("Unterminated property shape for ${property}")
    return rdf[start..<(end + close.size)]
  }

  private Str instanceBlock(Str rdf, Str id)
  {
    start := rdf.index("temp:${id}\n")
    if (start == null) throw Err("Missing instance ${id}")
    end := rdf.index("\n.\n", start)
    if (end == null) throw Err("Unterminated instance ${id}")
    return rdf[start..<(end + 3)]
  }

  private Str resourceBlock(Str rdf, Str resource)
  {
    start := rdf.index("${resource}\n")
    if (start == null) throw Err("Missing resource ${resource}")
    end := rdf.index("\n.\n", start)
    if (end == null) throw Err("Unterminated resource ${resource}")
    return rdf[start..<(end + 3)]
  }

  private Int countMatches(Str source, Str match)
  {
    count := 0
    offset := 0
    while (true)
    {
      found := source.index(match, offset)
      if (found == null) return count
      count++
      offset = found + match.size
    }
    return count
  }
}
