//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Jan 2019  Matthew Giannini  Creation
//

@Js class IriTest : Test
{
  [Str:Str] nsMap :=
  [
    "phIoT": "http://project-haystack.org/phIoT#"
  ]

  Void testEquality()
  {
    i1 := Iri("http://project-haystack.org/ph#foo")
    i2 := Iri("http://project-haystack.org/ph#", "foo")
    verifyEq(i1, i1)
    verifyEq(i1, i2)
    verifyNotEq(i1, Iri("http:/project-haystack.org/ph#", "Foo"))

    i1 = Iri("phIot:foo")
    i2 = Iri("phIot:", "foo")
    verifyEq(i1, i2)
    verifyNotEq(i1, Iri("phiot:", "foo"))
  }

  Void testFullIri()
  {
    i1 := Iri("phIoT:foo")
    i2 := Iri("http://project-haystack.org/phIoT#foo")
    verifyNotEq(i1, i2)
    verifyEq(i2, i1.fullIri(nsMap))
    verifyEq(i2, i2.fullIri(nsMap))
  }

  Void testPrefixIri()
  {
    i1 := Iri("phIoT:foo")
    i2 := Iri("http://project-haystack.org/phIoT#foo")
    verifyNotEq(i1, i2)
    verifyEq(i1, i2.prefixIri(nsMap))
    verifyEq(i1, i1.prefixIri(nsMap))
  }

  Void testBlankNode()
  {
    b1 := Iri.bnode
    verify(b1.isBlankNode)
    b2 := Iri.bnode
    verifyNotEq(b1, b2)
    verifyEq(Iri.bnode("foo"), Iri.bnode("foo"))
  }
}