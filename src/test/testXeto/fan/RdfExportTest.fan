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

  private Str export(Str src)
  {
    ns  := createNamespace(["sys"])
    lib := ns.compileTempLib(src)
    buf := Buf()
    RdfExporter(ns, buf.out, Etc.dict0).start.lib(lib).end
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
