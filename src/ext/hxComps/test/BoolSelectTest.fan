//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

class BoolSelectTest : HxCompTest
{
  static const Str[] inputs := ["inA", "inB", "inC", "inD", "inE",
                                "inF", "inG", "inH", "inI", "inJ"]

  ** Inputs and out are StatusBool in the spec and the Fantom accessors
  Void testTypes()
  {
    spec := ns.spec("hx.comps::BoolSelect")
    inputs.dup.add("out").each |n|
    {
      verifyEq(spec.slot(n).type.qname, "hx.comps::StatusBool", n)
      verify(spec.slot(n).isMaybe, n)
      verifyEq(BoolSelect#.method(n).returns, StatusBool?#, n)
    }
    verifyEq(ns.spec("hx.comps::ValSelect").slot("out").type.qname, "hx.comps::StatusVal")
  }

  Void testSelect()
  {
    TestHxCompContext().asCur |cx|
    {
      c := createAndExec("BoolSelect")
      c.set("numInputs", 10)
      inputs.each |sel, i|
      {
        inputs.each |n| { c.set(n, sb(n == sel)) }
        setAndExec(c, "select", sn(i + 1))
        verifyEq(c.get("out"), sb(true), sel)
      }

      c.set("inA", sb(false, Status.fault))
      setAndExec(c, "select", sn(1))
      verifyEq(c.get("out"), sb(false, Status.fault))
      setAndExec(c, "inA", null)
      verifyNull(c.get("out"))
      setAndExec(c, "inA", sb(true))
      setAndExec(c, "select", null)
      verifyNull(c.get("out"))
    }
  }

  ** A linked Bool reaches out, and a null over the link gives a null out
  Void testLink()
  {
    TestHxCompContext().asCur |cx|
    {
      k := createAndExec("BoolConst")
      s := createAndExec("BoolSelect")
      k.set("out", sb(true))
      s.set("select", sn(1))
      s.set("links", s.links.add("inA", Etc.link(k.id, "out")))
      cs.execute
      cs.execute
      verifyEq(s.get("out"), sb(true))

      k.set("out", null)
      cs.execute
      cs.execute
      verifyNull(s.get("out"))
    }
  }

  ** A saved space with a link into a Bool input loads, and saves it as a link
  Void testSavedLink()
  {
    TestHxCompContext().asCur |cx|
    {
      cs.loadXeto(
        Str<|@root: Folder {
               k @k: BoolConst { out: StatusBool { val: "true" } }
               s @s: BoolSelect {
                 select: StatusNumber { val: 2 }
                 links: { inB: Link { fromRef: @k, fromSlot: "out" } }
               }
             }|>)
      cs.execute
      cs.execute
      out := (cs.root->s as Comp).get("out")
      verifyEq(out, sb(true))
      verify(out is StatusBool)
      saved := cs.saveXeto
      verify(saved.contains("fromRef: @k"), saved)
      verifyFalse(saved.contains("inB: StatusBool"), saved)
    }
  }
}
