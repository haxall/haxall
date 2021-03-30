//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Jan 2019  Matthew Giannini  Creation
//

@Js class TurtleOutStreamTest : Test
{
  private static const Str tab  := "    "
  private static const Str tab2 := "${tab}${tab}"

  Buf b := Buf()
  TurtleOutStream writer(Buf buf := b)
  {
    TurtleOutStream(buf.clear.out)
      .setNs("t", "http://skyfoundry.com/rdf/test#")
      .setNs("phIoT", "http://project-haystack.org/phIoT#")
  }

  Void testPrefixes()
  {
    writer.finish
    verifyTurtle("")
  }

  Void testPrefixCaseSensitivity()
  {
    writer.writeStmt(Iri("phIoT:area"), Iri("phiot:foo"), 1).finish
    verifyTurtle("phIoT:area <phiot:foo> 1 .")
  }

  Void testPrefixedStmt()
  {
    writer.writeStmt(Iri("t:foo"), Iri("rdf:type"), Iri("t:Foo")).finish
    verifyTurtle("t:foo a t:Foo .")
  }

  Void testExpandedStmt()
  {
    writer.writeStmt(Iri("x:foo"), Iri("x:type"), Iri("x:Foo")).finish
    verifyTurtle("<x:foo> <x:type> <x:Foo> .")
  }

  Void testDifferentSubjects()
  {
    writer.writeStmt(Iri("t:foo"), Iri("rdf:type"), Iri("t:Foo"))
      .writeStmt(Iri("t:foo1"), Iri("rdf:type"), Iri("t:Foo")).finish
    verifyTurtle("""t:foo a t:Foo .

                    t:foo1 a t:Foo .""")
  }

  Void testSameSubjWithDifferentPreds()
  {
    writer.writeStmt(Iri("t:foo"), Iri("rdf:type"), Iri("t:Foo"))
      .writeStmt(Iri("t:foo"), Iri("t:name"), "Matthew")
      .writeStmt(Iri("t:foo"), Iri("t:email"), "matthew@skyfoundry.com").finish
    verifyTurtle("""t:foo a t:Foo ;
                    ${tab}t:name "Matthew" ;
                    ${tab}t:email "matthew@skyfoundry.com" .""")
  }

  Void testSameSubjPredWithDifferentObjects()
  {
    writer.writeStmt(Iri("t:foo"), Iri("rdf:type"), Iri("t:Obj"))
      .writeStmt(Iri("t:foo"), Iri("rdf:type"), Iri("t:BaseFoo"))
      .writeStmt(Iri("t:foo"), Iri("rdf:type"), Iri("t:Foo")).finish
    verifyTurtle("""t:foo a t:Obj,
                    ${tab2}t:BaseFoo,
                    ${tab2}t:Foo .""")
  }

  Void testCustomDataType()
  {
    writer.writeStmt(Iri("t:foo"), Iri("t:type"), Str#, Iri("https://fantom.org/types#sys::Type")).finish
    verifyTurtle(Str<|t:foo t:type "sys::Str"^^<https://fantom.org/types#sys::Type> .|>)
  }

  Void testBlankNodes()
  {
    writer.writeStmt(Iri.bnode("123-456"), Iri("phIoT:siteRef"), Iri.bnode("abc-123")).finish
    verifyTurtle("_:123-456 phIoT:siteRef _:abc-123 .")
  }

  private Void verifyTurtle(Str expected, Str ttl := this.b.flip.readAllStr)
  {
    if (!expected.isEmpty) expected = "\n${expected}\n"
    expected = """@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
                  @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
                  @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
                  @prefix t: <http://skyfoundry.com/rdf/test#> .
                  @prefix phIoT: <http://project-haystack.org/phIoT#> .
                  ${expected}"""
    try
      verifyEq(expected, ttl)
    catch (Err e)
    {
      echo("Expected:\n$expected\n---\nActual:\n$ttl\n---\n")
      throw e
    }
  }
}