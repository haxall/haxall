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
    verify(rdf.contains("sh:path temp:Reading.value ;\n    sh:datatype xsd:double ;"))
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
               value: Number <minVal:1.5, maxVal:2.5>
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

    value := propertyShape(rdf, "Reading.value")
    verify(value.contains("sh:datatype xsd:double ;"))
    verify(value.contains("sh:minInclusive \"1.5\"^^xsd:double ;"))
    verify(value.contains("sh:maxInclusive \"2.5\"^^xsd:double ;"))

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

  Void testCompleteSupportedProfileClosure()
  {
    src := Str<|Code : Scalar <pattern:"[A-Z]{2}">

                 Suit : Enum { clubs <key:"Clubs"> }
                 HeatingProcess : Choice
                 HotWaterHeating : HeatingProcess { hotWaterHeating }
                 SteamHeating : HeatingProcess { steamHeating }

                 Site : Dict { dis: Str }
                 Related : Dict
                 Address : Dict { city: Str }
                 Named : Dict { dis: Str }
                 Located : Dict { geoCity: Str }
                 NamedLocation : Named & Located
                 Heating : Dict
                 Cooling : Dict
                 ThermalProcess : Heating | Cooling

                 Asset : Dict {
                   *height: Number?<minVal:0, maxVal:300>
                 }

                 Equip : Asset <doc:"Line one\nLine \"two\" \\ dollar \$"> {
                   label: Str <nonEmpty, minSize:2, maxSize:40>
                   code: Code
                   count: Int <minVal:1, maxVal:60>
                   value: Number
                   enabled: Bool
                   commissioned: Date
                   observedAt: Time
                   timestamp: DateTime
                   source: Uri
                   zone: TimeZone
                   anything: Obj
                   suit: Suit
                   siteRef: Ref<of:Site>
                   related: MultiRef?<of:Related>
                   address: Address
                   names: List<of:Str, minSize:2, maxSize:3>
                   addresses: List<of:Address, nonEmpty>
                   heatingProcesses: HeatingProcess <multiChoice>
                   points: Query<of:Related, via:"related*">
                   equip
                   fixed: Str <invariant> "ok"
                   height: Int?<minVal:100>
                   unit: Unit <quantity:"temperature">
                   percent: Number <unit:"%">
                 }

                 @site1: Site { dis:"HQ" }
                 @related1: Related {}
                 @equip1: Equip {
                   label: "AHU-1"
                   code: Code "AB"
                   count: 7
                   value: 1.5
                   enabled: "true"
                   commissioned: 2026-08-18
                   observedAt: 02:30:00
                   timestamp: 2026-08-18T10:00:00Z
                   source: Uri "https://example.com/a?x=1&y=2"
                   zone: TimeZone "Chicago"
                   anything: "free"
                   suit: "Clubs"
                   siteRef: @site1
                   related: MultiRef { @related1 }
                   address: Address { city:"Richmond" }
                   names: {"first", "second"}
                   addresses: { Address { city:"Norfolk" } }
                   hotWaterHeating
                   steamHeating
                   equip
                   imported
                   unit: Unit "°F"
                   percent: Number "50%"
                 }|>

    mappings := RdfQudtMappings(
      "fahrenheit=DEG_F\npercent=PERCENT\n",
      "temperature=Temperature\n")
    first := exportWithMappings(src, mappings)
    second := exportWithMappings(src, mappings)
    verifyEq(first, second)

    equip := instanceBlock(first, "equip1")
    verify(equip.contains("temp:Equip.label \"AHU-1\"^^xsd:string ;"), equip)
    verify(equip.contains("temp:Equip.observedAt \"02:30:00\"^^xsd:time ;"), equip)
    verify(equip.contains("temp:Equip.timestamp \"2026-08-18T10:00:00Z\"^^xsd:dateTime ;"), equip)
    verify(equip.contains("temp:Equip.source \"https://example.com/a?x=1&y=2\"^^xsd:anyURI ;"), equip)
    verify(equip.contains("temp:Equip.anything \"free\"^^xsd:string ;"), equip)
    verify(equip.contains("temp:Equip.siteRef temp:site1 ;"), equip)
    verify(equip.contains("temp:Equip.address ["), equip)
    verify(equip.contains("temp:Equip.names ("), equip)
    verify(equip.contains("temp:Equip.heatingProcesses temp:HotWaterHeating ;"), equip)
    verify(equip.contains("qudt:numericValue \"50.0\"^^xsd:double ;"), equip)
    verify(equip.contains("sys:hasMarker temp:Equip.imported ;"), equip)
    verifyFalse(equip.contains("temp:Equip.points"), equip)

    firstName := equip.index("\"first\"^^xsd:string")
    secondName := equip.index("\"second\"^^xsd:string")
    verify(firstName != null && secondName != null && firstName < secondName, equip)
    verify(first.contains("rdfs:comment \"Line one\\nLine \\\"two\\\" \\\\ dollar \$\"@en"), first)
    verify(first.contains("sh:zeroOrMorePath temp:Equip.related"), first)
    verify(first.contains("rdfs:subPropertyOf temp:Asset.height ;"), first)
    verify(first.contains("rdfs:subClassOf temp:Named, temp:Located ;"), first)
    verify(first.contains("temp:Heating rdfs:subClassOf temp:ThermalProcess ."), first)
    verify(first.contains("temp:Cooling rdfs:subClassOf temp:ThermalProcess ."), first)
    verifyFalse(propertyShape(first, "Equip.zone").contains("sh:in"), first)
  }

  Void testUnsupportedSystemScalarFailsClosed()
  {
    verifyErrMsg(UnsupportedErr#, "RDF scalar datatype not supported: sys::Version")
    {
      export(Str<|Reading : Dict { version: Version }|>)
    }
  }

  Void testUnmappedMetadataIsOmitted()
  {
    plain := export(Str<|Person : Dict { dis: Str }|>)
    annotated := export(
      Str<|+Spec { icon: Str? }

             Person : Dict <icon:"user"> {
               dis: Str <icon:"label">
             }|>)

    verifyEq(resourceBlock(annotated, "temp:Person"), resourceBlock(plain, "temp:Person"))
    verifyEq(resourceBlock(annotated, "temp:Person.dis"), resourceBlock(plain, "temp:Person.dis"))
    verifyFalse(annotated.contains("icon"), annotated)
  }

  Void testOtherCoreTypeInventory()
  {
    rdf := export(
      Str<|Failure : Err
             Envelope : Dict { failure: Failure? }|>)
    verify(rdf.contains("temp:Failure\n  a sys:Class ;"), rdf)
    verify(rdf.contains("rdfs:subClassOf sys:Err ;"), rdf)
    verify(propertyShape(rdf, "Envelope.failure").contains("sh:node temp:Failure ;"), rdf)

    ["None", "NA", "Duration", "Version", "Buf", "Span", "Filter", "BuildVar"].each |type|
    {
      verifyUnsupported("Holder : Dict { value: ${type} }", "RDF scalar datatype not supported: sys::${type}")
    }
    verifyUnsupported("Holder : Dict { value: Grid }", "RDF Grid mapping not supported")
    verifyUnsupported("Holder : Dict { value: Collection }", "RDF Collection mapping not supported")
    verifyUnsupported("Holder : Dict { value: Func }", "RDF Func mapping not supported")
    verifyUnsupported("Holder : Dict { value: Interface }", "RDF Interface mapping not supported")
    verifyUnsupported("Holder : Dict { value: Funcs }", "RDF Interface mapping not supported")
  }

  Void testClosureDiagnosticsFailClosed()
  {
    try
    {
      export(Str<|Point : Dict
                   Equip : Dict { points: Query { point: Point } }|>)
      fail("Expected required query body member to fail closed")
    }
    catch (UnsupportedErr err)
    {
      verify(err.msg.contains("RDF query body mapping not supported for required member"), err.msg)
      verify(err.msg.endsWith("::Equip.points.point"), err.msg)
    }

    try
    {
      export(Str<|Node : Dict { parent: Ref<of:This> }|>)
      fail("Expected parent-relative Ref to fail closed")
    }
    catch (UnsupportedErr err)
    {
      verify(err.msg.contains("RDF parent-relative This mapping not supported for"), err.msg)
      verify(err.msg.endsWith("::Node.parent"), err.msg)
    }

    ns := createNamespace(["sys"])
    colonId := Etc.makeDict(["id":Ref("sys::op:bad"), "spec":Ref("sys::Dict")])
    buf := Buf()
    RdfExporter(ns, buf.out, Etc.dict0).start.instance(colonId).end
    verify(buf.flip.readAllStr.contains("#op:bad>"))

    unknownLibId := Etc.makeDict(["id":Ref("missing.lib::bad"), "spec":Ref("sys::Dict")])
    verifyErrMsg(UnsupportedErr#, "Concrete Xeto library version unavailable for missing.lib")
    {
      RdfExporter(ns, Buf().out, Etc.dict0).start.instance(unknownLibId).end
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

  Void testLibraryProjectionProfiles()
  {
    src := Str<|Widget : Dict { widget }
                 @widget1: Widget {}|>
    schema := exportWithOpts(src, Etc.makeDict(["schemaOnly":Marker.val]))
    verify(schema.contains("temp:Widget\n  a sys:Class"), schema)
    verifyFalse(schema.contains("temp:widget1"), schema)

    instances := exportWithOpts(src, Etc.makeDict(["instancesOnly":Marker.val]))
    verify(instances.contains("temp:widget1"), instances)
    verify(instances.contains("sys:hasMarker temp:Widget.widget"), instances)
    verifyFalse(instances.contains("a sh:NodeShape"), instances)
    verifyFalse(instances.contains("a owl:Ontology"), instances)
  }

  Void testMixinInstancePropertyOwnership()
  {
    rdf := export(
      Str<|+Entity { orgRef: Ref<of:Org> }
             Org : Dict
             Employee : Entity

             @org1: Org {}
             @entity1: Entity { orgRef: @org1 }
             @employee1: Employee { orgRef: @org1 }|>)

    entity := instanceBlock(rdf, "entity1")
    verify(entity.contains("temp:Entity.orgRef temp:org1 ;"), entity)
    verifyFalse(entity.contains("sys:Entity.orgRef"), entity)

    employee := instanceBlock(rdf, "employee1")
    verify(employee.contains("temp:Entity.orgRef temp:org1 ;"), employee)
    verifyFalse(employee.contains("temp:Employee.orgRef"), employee)
  }

  Void testDirectInstanceFindsInstalledMixinProperty()
  {
    ns := createNamespace(["sys", "hx"])
    instance := Etc.makeDict([
      "id": Ref("hx::entity1"),
      "spec": Ref("sys::Entity"),
      "mod": DateTime("2026-08-26T12:00:00Z UTC")])
    buf := Buf()
    RdfExporter(ns, buf.out, Etc.dict0).start.instance(instance).end
    rdf := buf.flip.readAllStr

    verify(rdf.contains("hx:Entity.mod \"2026-08-26T12:00:00Z\"^^xsd:dateTime ;"), rdf)
    verifyFalse(rdf.contains("sys:Entity.mod"), rdf)
  }

  Void testAmbiguousMixinInstancePropertyFailsClosed()
  {
    ns := createNamespace(["sys", "hx"])
    lib := ns.compileTempLib(
      Str<|+Entity { mod: DateTime? }
             @entity1: Entity { mod: 2026-08-26T12:00:00Z }|>)
    try
    {
      RdfExporter(ns, Buf().out, Etc.dict0).start.lib(lib).end
      fail("Expected ambiguous mixin instance property to fail closed")
    }
    catch (UnsupportedErr err)
    {
      verify(err.msg.startsWith("Ambiguous mixin property for sys::Entity.mod:"), err.msg)
      verify(err.msg.contains("hx::Entity.mod"), err.msg)
      verify(err.msg.contains("${lib.name}::Entity.mod"), err.msg)
    }
  }

  Void testMissingMixinTargetRejectedAtCompileBoundary()
  {
    ns := createNamespace(["sys"])
    try
    {
      ns.compileTempLib("+Missing { value: Str? }")
      fail("Expected missing mixin target to fail during compilation")
    }
    catch (XetoCompilerErr err)
    {
      verify(err.msg.contains("Unresolved spec: Missing"), err.msg)
    }
  }

  Void testMissingReferenceDoesNotExportTypeDefault()
  {
    rdf := export(
      Str<|Target : Dict
             Holder : Dict { targetRef: Ref<of:Target> }

             @holder1: Holder {}|>)

    holder := instanceBlock(rdf, "holder1")
    verifyFalse(holder.contains("Holder.targetRef"), holder)
  }

  Void testLexicalSerialization()
  {
    rdf := export(
      Str<|State : Enum {
               unusual <key:"line\n\"quoted\"\\slash Ω">
             }

             Reading : Dict <doc:"line\n\"quoted\"\\slash Ω"> {
               state: State
               large: Int <minVal:-9223372036854775808, maxVal:9223372036854775807>
               tiny: Number <minVal:1e-7, maxVal:1e20>
               ratio: Float <minVal:1e-7, maxVal:1e20>
               signedZero: Float
               notANumber: Float
               positiveInfinity: Float
               negativeInfinity: Float
             }

             @reading1: Reading {
               state: "line\n\"quoted\"\\slash Ω"
               large: 9223372036854775807
               tiny: 1e-7
               ratio: 1e-7
               signedZero: -0.0
               notANumber: "NaN"
               positiveInfinity: "INF"
               negativeInfinity: "-INF"
             }|>)

    verify(rdf.contains("\"line\\n\\\"quoted\\\"\\\\slash Ω\"^^xsd:string"), rdf)
    verify(rdf.contains("rdfs:comment \"line\\n\\\"quoted\\\"\\\\slash Ω\"@en"), rdf)
    verify(rdf.contains("sh:minInclusive -9223372036854775808 ;"), rdf)
    verify(rdf.contains("sh:maxInclusive 9223372036854775807 ;"), rdf)
    verify(rdf.contains("sh:minInclusive \"1.0E-7\"^^xsd:double ;"), rdf)
    verify(rdf.contains("sh:maxInclusive \"1.0E20\"^^xsd:double ;"), rdf)
    verify(rdf.contains("\"1.0E-7\"^^xsd:double"), rdf)
    verify(rdf.contains("sh:datatype xsd:double ;"), rdf)
    verify(rdf.contains("sh:minInclusive \"1.0E-7\"^^xsd:double ;"), rdf)
    verify(rdf.contains("sh:maxInclusive \"1.0E20\"^^xsd:double ;"), rdf)
    verify(rdf.contains("\"1.0E-7\"^^xsd:double"), rdf)
    verify(rdf.contains("\"-0.0\"^^xsd:double"), rdf)
    verify(rdf.contains("\"NaN\"^^xsd:double"), rdf)
    verify(rdf.contains("\"INF\"^^xsd:double"), rdf)
    verify(rdf.contains("\"-INF\"^^xsd:double"), rdf)

    controlRdf := export("Controlled : Dict <doc:\"backspace\\u0008 form-feed\\u000C control\\u0001\">")
    verify(controlRdf.contains("rdfs:comment \"backspace\\b form-feed\\f control\\u0001\"@en"), controlRdf)

    ns := createNamespace(["sys"])
    sysVersion := ns.lib("sys").version
    ["sys::tail.", "sys::name~one", "sys::op:name"].each |id|
    {
      instance := Etc.makeDict(["id":Ref(id), "spec":Ref("sys::Dict")])
      buf := Buf()
      RdfExporter(ns, buf.out, Etc.dict0).start.instance(instance).end
      rendered := buf.flip.readAllStr
      verify(rendered.contains("<http://xeto.dev/rdf/sys-${sysVersion}#"), rendered)
    }
  }

  Void testNumberSpecialValuesUseDouble()
  {
    rdf := export(
      "Reading : Dict { nan: Number, pos: Number, neg: Number }\n" +
      "@reading1: Reading { nan: \"NaN\", pos: \"INF\", neg: \"-INF\" }")
    verify(rdf.contains("\"NaN\"^^xsd:double"), rdf)
    verify(rdf.contains("\"INF\"^^xsd:double"), rdf)
    verify(rdf.contains("\"-INF\"^^xsd:double"), rdf)
  }

  Void testNaNFloatBoundFailsClosed()
  {
    verifyUnsupportedFragments(
      "Reading : Dict { value: Float <minVal:\"NaN\"> }",
      ["Invalid numeric metadata for", "Reading.value.minVal", "NaN is not an ordered bound"])
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
    verify(numbers.contains("sh:datatype xsd:double ;"), numbers)
    verify(numbers.contains("sh:minCount 1 ;"), numbers)

    addresses := propertyShape(rdf, "Batch.addresses")
    verify(addresses.contains("sh:class temp:Address ;"), addresses)

    batch := instanceBlock(rdf, "batch1")
    alpha := batch.index("\"alpha\"^^xsd:string")
    beta  := batch.index("\"beta\"^^xsd:string")
    verify(alpha != null && beta != null && alpha < beta, batch)
    verify(batch.contains("\"1.0\"^^xsd:double"), batch)
    verify(batch.contains("\"2.5\"^^xsd:double"), batch)
    richmond := batch.index("\"Richmond\"^^xsd:string")
    norfolk  := batch.index("\"Norfolk\"^^xsd:string")
    verify(richmond != null && norfolk != null && richmond < norfolk, batch)
  }

  Void testQueryPropertyPaths()
  {
    rdf := export(
      Str<|Equip : Dict {
               points: Query<of:Point, inverse:"Point.equips">
               plain: Query<of:Point>
             }

             Point : Dict {
               equipRef: Ref<of:Equip>
               equips: Query<of:Equip, via:"equipRef+">
             }

             @equip1: Equip {}
             @point1: Point { equipRef: @equip1 }|>)

    points := propertyShape(rdf, "[ sh:oneOrMorePath [ sh:inversePath temp:Point.equipRef ] ]")
    verify(points.contains("sh:class temp:Point ;"), points)
    verifyFalse(points.contains("sh:minCount"), points)
    verifyFalse(points.contains("sh:maxCount"), points)

    equips := propertyShape(rdf, "[ sh:oneOrMorePath temp:Point.equipRef ]")
    verify(equips.contains("sh:class temp:Equip ;"), equips)
    verifyFalse(equips.contains("sh:minCount"), equips)
    verifyFalse(equips.contains("sh:maxCount"), equips)

    plain := propertyShape(rdf, "Equip.plain")
    verify(plain.contains("sh:class temp:Point ;"), plain)
    verifyFalse(plain.contains("sh:minCount"), plain)
    verifyFalse(plain.contains("sh:maxCount"), plain)

    point := instanceBlock(rdf, "point1")
    verify(point.contains("temp:Point.equipRef temp:equip1 ;"), point)
    equip := instanceBlock(rdf, "equip1")
    verifyFalse(equip.contains("temp:Equip.points"), equip)
  }

  Void testQueryPathValidation()
  {
    verifyUnsupportedFragments(
      Str<|Point : Dict
           Holder : Dict {
             values: Query<of:Point, via:"pointRef", inverse:"Point.values">
           }|>, ["Holder.values", "cannot declare both via and inverse"])

    verifyUnsupportedFragments(
      Str<|Point : Dict
           Holder : Dict { values: Query<of:Point, via:""> }|>,
      ["Empty query path", "Holder.values"])
    verifyUnsupportedFragments(
      Str<|Point : Dict
           Holder : Dict { values: Query<of:Point, inverse:""> }|>,
      ["Empty query path", "Holder.values"])

    verifyUnsupportedFragments(
      Str<|Point : Dict
           Holder : Dict { values: Query<of:Point, via:"pointRef++"> }|>,
      ["Invalid query path", "Holder.values", "pointRef++"])
    verifyUnsupportedFragments(
      Str<|Point : Dict
           Holder : Dict {
             values: Query<of:Point, inverse:"Point.equipRef+">
           }|>, ["Invalid query path", "Holder.values", "Point.equipRef+"])

    verifyUnsupportedFragments(
      Str<|Equip : Dict {
             points: Query<of:Point, inverse:"Point.equips">
           }
           Point : Dict { equips: Query<of:Equip> }|>,
      ["Equip.points", "must reference a via query", "Point.equips"])

    rdf := export(
      Str<|Equip : Dict {
               points: Query<of:Point, inverse:"Point.equipRef">
             }
             Point : Dict { equipRef: Ref<of:Equip, maybe> }|>)
    direct := propertyShape(rdf, "[ sh:inversePath temp:Point.equipRef ]")
    verify(direct.contains("sh:class temp:Point ;"), direct)
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
    verify(rdf.contains("sh:minInclusive \"0.0\"^^xsd:double ;"), rdf)
    verify(rdf.contains("sh:maxInclusive \"100.0\"^^xsd:double ;"), rdf)
    verify(rdf.contains("sh:path qudt:unit ;"), rdf)
    verify(rdf.contains("sh:hasValue unit:PERCENT ;"), rdf)
    verify(rdf.contains("sh:hasValue quantitykind:Power"), rdf)

    reading := instanceBlock(rdf, "reading1")
    verify(reading.contains("temp:Reading.unit unit:DEG_F ;"), reading)
    verify(reading.contains("qudt:numericValue \"50.0\"^^xsd:double ;"), reading)
    verify(reading.contains("qudt:unit unit:PERCENT"), reading)
    verify(reading.contains("qudt:numericValue \"1.0\"^^xsd:double ;"), reading)
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
    return exportWithOpts(src, Etc.dict0)
  }

  private Str exportWithOpts(Str src, Dict opts)
  {
    ns  := createNamespace(["sys"])
    lib := ns.compileTempLib(src)
    buf := Buf()
    RdfExporter(ns, buf.out, opts).start.lib(lib).end
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
    path := property.startsWith("[")
      ? "sh:path ${property} ;"
      : "sh:path temp:${property} ;"
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

  private Void verifyUnsupported(Str src, Str expected)
  {
    try
    {
      export(src)
      fail("Expected unsupported RDF mapping: ${src}")
    }
    catch (UnsupportedErr err)
    {
      verify(err.msg.contains(expected), err.msg)
    }
  }

  private Void verifyUnsupportedFragments(Str src, Str[] expected)
  {
    try
    {
      export(src)
      fail("Expected unsupported RDF mapping: ${src}")
    }
    catch (UnsupportedErr err)
    {
      expected.each |fragment| { verify(err.msg.contains(fragment), err.msg) }
    }
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
