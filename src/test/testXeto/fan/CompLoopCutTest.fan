//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using xetom
using haystack

**
** CompLoopCutTest covers how a 'loopCut' link is sorted and pushed.  The
** graphs are TestNumberAdd comps (out = in1 + in2), and each trace lists
** every comp's out after each cycle.
**
@Js
class CompLoopCutTest : AbstractXetoTest
{
  CompSpace? cs

  override Void teardown()
  {
    CompSpace.uninstall
    super.teardown
  }

  ** A loop cut once or twice reads the previous cycle's value in every
  ** creation order, and a loop with no cut runs in creation order
  Void testLoop()
  {
    uncut := Str[,]
    perms(2).each |p|
    {
      m := build(["a", "b"], p, [1, 10])
      link(m["a"], m["b"], true)
      link(m["b"], m["a"], false)
      verifyEq(trace(m), "a=11,22,33 b=10,21,32", "$p")

      m = build(["a", "b"], p, [1, 10])
      link(m["a"], m["b"], true)
      link(m["b"], m["a"], true)
      verifyEq(trace(m), "a=1,11,12 b=10,11,21", "$p")

      m = build(["a", "b"], p, [1, 10])
      link(m["a"], m["b"], false)
      link(m["b"], m["a"], false)
      uncut.add(trace(m))
    }
    verifyEq(uncut.sort, ["a=1,12,23 b=11,22,33", "a=11,22,33 b=10,21,32"])

    // x feeds loop a -> b -> c -> a, cut at c -> a
    perms(4).each |p|
    {
      m := build(["a", "b", "c", "x"], p, [0, 10, 100, 1])
      link(m["x"], m["a"], false, "in2")
      link(m["a"], m["b"], false)
      link(m["b"], m["c"], false)
      link(m["c"], m["a"], true)
      verifyEq(trace(m), "a=1,112,223 b=11,122,233 c=111,222,333 x=1,1,1", "$p")
    }
  }

  ** A cut push lands at the end of its own cycle, once; only a Marker cuts
  Void testDelivery()
  {
    perms(2).each |p|
    {
      m := build(["a", "b"], p, [1, 10])
      link(m["a"], m["b"], true)
      verifyEq(trace(m, 1), "a=1 b=10", "$p")
      verifyEq(m["b"]->in1, n(1))
      verifyEq(trace(m, 2), "a=1,1 b=11,11", "$p")
      m["b"].set("in1", n(100))
      verifyEq(trace(m, 2), "a=1,1 b=110,110", "$p")
    }

    [false, None.val].each |v|
    {
      m := build(["a", "b"], [0, 1], [1, 10])
      m["b"].set("links", Etc.links(null).add("in1",
        Etc.linkWrap(Etc.dict3("fromRef", m["a"].id, "fromSlot", "out", "loopCut", v))))
      verifyEq(trace(m, 1), "a=1 b=11", "$v")
    }
  }

  ** A cut into a method slot calls the method at the end of the cycle,
  ** and the result is pushed on the next cycle
  Void testFuncSlot()
  {
    [false, true].each |cut|
    {
      newSpace
      d := create("TestFoo")
      e := create("TestFoo")
      f := create("TestFoo")
      link(d, e, cut, "methodEcho", "a")
      link(e, f, false, "c", "methodEcho")
      verifyEq(trace(["f": f], 2, "c"), cut ? "f=null,alpha" : "f=alpha,alpha")
      d.set("a", "x")
      verifyEq(trace(["f": f], 2, "c"), cut ? "f=alpha,x" : "f=x,x")
    }
  }

  ** A cut push into a comp removed during the cycle is dropped, and the
  ** same push into a mounted comp lands
  Void testUnmounted()
  {
    space := LoopCutUnmountSpace(createNamespace(CompTest.loadTestLibs))
    newSpace("TestFolder {}", space)
    a := create("TestNumberAdd")
    b := create("TestNumberAdd")
    c := create("TestNumberAdd")
    a.set("in2", n(1))
    link(a, b, true)
    link(a, c, true)
    space.watch = a
    space.victim = b
    verifyEq(trace(["a": a], 1), "a=1")
    verifyEq(b.isMounted, false)
    verifyEq(b->in1, n(0))
    verifyEq(c->in1, n(1))
  }

  ** Save and load keep the cut, and the spec save path writes it beside the link
  Void testSave()
  {
    m := build(["a", "b"], [0, 1], [1, 10])
    link(m["a"], m["b"], true)
    link(m["b"], m["a"], false)
    xeto := cs.saveXeto
    newSpace(xeto)
    verifyEq(cuts(cs.readById(m["b"].id)), [true])
    verifyEq(cuts(cs.readById(m["a"].id)), [false])
    verifyEq(cs.saveXeto, xeto)

    ast := CompUtil.compSaveToAstSlots(cs.root, "do")
    verifyEq(astSlot(ast, m["b"].name)->link, m["a"].name + ".out")
    verifyEq(astSlot(ast, m["b"].name)["loopCut"], Marker.val)
    verifyEq(astSlot(ast, m["a"].name).has("loopCut"), false)
  }

  ** A loopCut beside a spec link cuts it, and a subtype that declares its
  ** own link is cut only by its own loopCut
  Void testSpec()
  {
    newSpace
    x := create("TestLoopCut")
    verifyEq(trace(Str:Comp["a": x->a, "b": x->b]), "a=11,22,33 b=10,21,32")
    ["TestLoopCut": true, "TestLoopCutSubSame": false, "TestLoopCutSubMoved": false,
     "TestLoopCutSubIn2": true, "TestLoopCutSubNone": false, "TestLoopCutSubDoc": true].each |cut, name|
    {
      verifyEq(cuts(create(name)->b), [cut], name)
    }
  }

  ** setLoopCut sets and clears a cut in place, and duplicate keeps it
  Void testEdit()
  {
    m := build(["a", "b", "y"], [0, 1, 2], [1, 10, 0])
    a := m["a"]; b := m["b"]; y := m["y"]
    edit.link(a.id, "out", b.id, "in1")
    edit.link(y.id, "out", b.id, "in1")
    edit.link(b.id, "out", a.id, "in1")
    edit.setLoopCut(a.id, "out", b.id, "in1", true)
    verifyEq(cuts(b), [true, false])
    edit.setLoopCut(a.id, "out", b.id, "in1", false)
    verifyEq(cuts(b), [false, false])
    verifyErr(Err#) { edit.setLoopCut(a.id, "in2", b.id, "in1", true) }

    edit.setLoopCut(a.id, "out", b.id, "in1", true)
    dups := edit.duplicate([a.id, b.id])
    verifyEq(dups[1].links.listOn("in1").first.fromRef, dups[0].id)
    verifyEq(cuts(dups[1]), [true])
    verifyEq(cuts(dups[0]), [false])
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void newSpace(Str xeto := "TestFolder {}", CompSpace? space := null)
  {
    CompSpace.uninstall
    cs = (space ?: CompSpace(createNamespace(CompTest.loadTestLibs))).install
    cs.loadXeto(xeto)
    cs.start
  }

  CompSpaceEdit edit() { ((MCompSpaceSpi)cs.spi).edit }

  Comp create(Str spec) { edit.create(cs.root.id, "hx.test.xeto::$spec") }

  ** Fresh space with a TestNumberAdd per name, created in perm order
  Str:Comp build(Str[] names, Int[] perm, Int[] in2)
  {
    newSpace
    m := Str:Comp[:]
    perm.each |i| { m[names[i]] = create("TestNumberAdd") }
    names.each |x, i| { m[x].set("in2", n(in2[i])) }
    return m
  }

  ** Link from.fromSlot -> to.toSlot, with the loopCut marker if cut
  Void link(Comp from, Comp to, Bool cut, Str toSlot := "in1", Str fromSlot := "out")
  {
    tags := Etc.dict2("fromRef", from.id, "fromSlot", fromSlot)
    to.set("links", to.links.add(toSlot, Etc.linkWrap(cut ? Etc.dictSet(tags, "loopCut", Marker.val) : tags)))
  }

  Bool[] cuts(Comp c) { c.links.listOn("in1").map |x->Bool| { CompUtil.isLoopCut(x) } }

  Dict astSlot(Dict ast, Str comp)
  {
    c := ((Grid)ast->slots).find |r| { r["name"] == comp }
    return ((Grid)c->slots).find |r| { r["name"] == "in1" }
  }

  ** Execute n cycles and list each comp's slot after each, by name
  Str trace(Str:Comp m, Int n := 3, Str slot := "out")
  {
    names := m.keys.sort
    Str[][] acc := names.map |x->Str[]| { Str[,] }
    n.times
    {
      TestAxonContext(cs.ns).asCur |cx| { cs.execute }
      names.each |x, i| { acc[i].add("" + m[x].get(slot)) }
    }
    return names.map |x, i->Str| { "$x=" + acc[i].join(",") }.join(" ")
  }

  ** Every permutation of 0..<n
  static Int[][] perms(Int n)
  {
    if (n == 0) return [Int[,]]
    acc := Int[][,]
    perms(n-1).each |p| { (0..p.size).each |i| { acc.add(p.dup.insert(i, n-1)) } }
    return acc
  }
}

**************************************************************************
** LoopCutUnmountSpace
**************************************************************************

** Space that removes the victim comp when the watched comp's out changes
@Js
internal class LoopCutUnmountSpace : CompSpace
{
  new make(Namespace ns) : super(ns) {}

  Comp? watch
  Comp? victim

  override Void onChange(CompChangeEvent e)
  {
    if (victim == null || e.comp !== watch || e.name != "out") return
    v := victim
    victim = null
    v.parent.remove(v.name)
  }
}
