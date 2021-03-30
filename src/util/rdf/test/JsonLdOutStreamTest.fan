//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Jan 2019  Matthew Giannini  Creation
//

@Js class JsonLdOutStreamTest : Test
{
  private static const Str tab  := "    "
  private static const Str tab2 := "${tab}${tab}"

  Buf b := Buf()
  JsonLdOutStream out(Buf buf := b)
  {
    JsonLdOutStream(buf.clear.out)
      .setNs("t", "http://skyfoundry.com/rdf/test#")
      .setNs("phIoT", "http://project-haystack.org/phIoT#")
  }

  private [Str:Obj] m() { [Str:Obj][:] { ordered = true } }

  Void testPrefixes()
  {
    out.finish
    verifyJson("")
  }

  Void testPrefixCaseSensitivity()
  {
    out.writeStmt(Iri("phIoT:area"), Iri("phiot:foo"), 1).finish
    verifyJson("""{"@id":"phIoT:area","phiot:foo":1}""")
  }

  Void testBlankNodes()
  {
    out.writeStmt(Iri.bnode("123-456"), Iri("phIoT:siteRef"), Iri.bnode("abc-123")).finish
    verifyJson("""{"@id":"_:123-456","phIoT:siteRef":{"@id":"_:abc-123"}}""")
  }

  Void testPrefixedStmt()
  {
    out.writeStmt(Iri("t:foo"), Iri("rdf:type"), Iri("t:Foo")).finish
    verifyJson("""{"@id":"t:foo","rdf:type":{"@id":"t:Foo"}}""")
  }

  Void testDifferentSubjects()
  {
    out.writeStmt(Iri("t:foo"), Iri("rdf:type"), Iri("t:Foo"))
       .writeStmt(Iri("t:foo1"), Iri("rdf:type"), Iri("t:Foo")).finish

    verifyJson(
      """{"@id":"t:foo","rdf:type":{"@id":"t:Foo"}},
         {"@id":"t:foo1","rdf:type":{"@id":"t:Foo"}}""")
  }

  Void testSameSubjWithDifferentPreds()
  {
    out.writeStmt(Iri("t:foo"), Iri("rdf:type"), Iri("t:Foo"))
      .writeStmt(Iri("t:foo"), Iri("t:name"), "Matthew")
      .writeStmt(Iri("t:foo"), Iri("t:email"), "matthew@skyfoundry.com").finish

    verifyJson(
      """{"@id":"t:foo","rdf:type":{"@id":"t:Foo"},"t:name":"Matthew","t:email":"matthew@skyfoundry.com"}""")
  }

  Void testSameSubjPredWithDifferentObjects()
  {
    out.writeStmt(Iri("t:foo"), Iri("rdf:type"), Iri("t:Obj"))
      .writeStmt(Iri("t:foo"), Iri("rdf:type"), Iri("t:BaseFoo"))
      .writeStmt(Iri("t:foo"), Iri("rdf:type"), Iri("t:Foo")).finish

    verifyJson(
      """{"@id":"t:foo","rdf:type":[{"@id":"t:Obj"},{"@id":"t:BaseFoo"},{"@id":"t:Foo"}]}""")
  }

  Void testCustomDataType()
  {
    out.writeStmt(Iri("t:foo"), Iri("t:type"), Str#, Iri("https://fantom.org/types#sys::Type")).finish
    verifyJson(
      """{"@id":"t:foo","t:type":{"@value":"sys::Str","@type":"https://fantom.org/types#sys::Type"}}""")
  }

  private Void verifyJson(Str graph, Str json := this.b.flip.readAllStr)
  {
    expected := """{
                   "@context":{"rdf":"http://www.w3.org/1999/02/22-rdf-syntax-ns#","rdfs":"http://www.w3.org/2000/01/rdf-schema#","xsd":"http://www.w3.org/2001/XMLSchema#","t":"http://skyfoundry.com/rdf/test#","phIoT":"http://project-haystack.org/phIoT#"},
                   "@graph":[${graph}]}"""
    try
      verifyEq(expected, json)
    catch (Err e)
    {
      echo("Expected:\n$expected\n---\nActual:\n$json\n---\n")
      throw e
    }
  }
}