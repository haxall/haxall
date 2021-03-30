//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Jan 2019  Matthew Giannini  Creation
//

@Js class StmtTest : Test
{
  [Str:Str] nsMap :=
  [
    "phIoT": "http://project-haystack.org/phIoT#"
  ]

  Void testEquality()
  {
    s1 := Iri("http://ph#foo")
    s2 := Iri("http://ph#bar")
    p1 := Iri("http://ph#is")

    verifyEq(Stmt(s1, p1, s1), Stmt(s1, p1, s1))
    verifyEq(Stmt(s1, p1, "foo"), Stmt(s1, p1, "foo"))
  }

  Void testNormalize()
  {
    preStmt := Stmt(Iri("phIoT:subj"), Iri("phIoT:pred"), Iri("phIoT:obj"))

    ns := nsMap["phIoT"]
    normStmt := Stmt(Iri("${ns}subj"), Iri("${ns}pred"), Iri("${ns}obj"))

    verifyNotEq(preStmt, normStmt)
    verifyEq(preStmt.normalize(nsMap), normStmt)
    verifyEq(normStmt.prefix(nsMap), preStmt)
  }
}