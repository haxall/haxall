//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//  10 Oct 2025  Matthew Giannini Creation
//

using concurrent
using xeto
using xetom
using haystack

**
** CompSpaceTest
**
class CompSpaceTest: AbstractXetoTest
{
  Void testUnmountRemovesTargetLinks()
  {
    ns := createNamespace(CompTest.loadTestLibs)
    cs := CompSpace(ns).load(CompTest.loadTestXeto)

    TestAdd c := cs.root.get("c")
    c.set("in2", TestVal(100))
    verifyEq(c.get("in2"), TestVal.makeNum(100))
    verifyEq(c.links.listOn("in2").size, 1)
    cs.root.remove("b")
    // echo(cs.save)
    verifyEq(c.links.listOn("in2").size, 0)
    verifyEq(c.get("in2"), TestVal.makeNum(0))
  }

//////////////////////////////////////////////////////////////////////////
// CompMap
//////////////////////////////////////////////////////////////////////////

  Void testCompMap()
  {
    // setup comp space
    cs := CompSpace(createNamespace(CompTest.loadTestLibs))
    Actor.locals[CompSpace.actorKey] = cs

    // init map with a-f
    m := CompMap()
    verifyCompMapSort(m, Comp[,])
    a := compMapAdd(m, "A", "0")
    b := compMapAdd(m, "B", "1")
    c := compMapAdd(m, "C", "2")
    d := compMapAdd(m, "D", "3")
    e := compMapAdd(m, "E", "4")
    f := compMapAdd(m, "F", "5")
    verifyCompMapSort(m, [a, b, c, d, e, f])

    // add some links f -> e -> d -> c -> b -> a
    link(f, e)
    link(e, d)
    link(d, c)
    link(c, b)
    link(b, a)
    verifyCompMapSort(m, [f, e, d, c, b, a])

    // add some links
    //  a -> b -> c -> d
    //  e -> f
    //  f -> b & c
    clearLinks(m)
    link(a, b)
    link(b, c)
    link(c, d)
    link(e, f)
    link(f, b)
    link(f, c)
    verifyCompMapSort(m, [a, e, f, b, c, d])

    // link cycle
    //  a -> b -> c -> a
    //  d -> e -> f
    clearLinks(m)
    link(a, b)
    link(b, c)
    link(c, a)
    link(d, e)
    link(d, e)
    link(e, f)
    verifyCompMapSort(m, [d, e, f, a, b, c])

    // remove a and c (leaving broken links)
    m.remove(a)
    m.remove(c)
    verifyCompMapSort(m, [b, d, e, f])

    // add and ensure slots are reused
    g := compMapAdd(m, "G", "6")
    h := compMapAdd(m, "H", "7")
    i := compMapAdd(m, "I", "8")
    verifyCompMapSort(m, [b, d, e, f, g, h, i])

    // cleanup
    Actor.locals.remove(CompSpace.actorKey)
  }

  Comp compMapAdd(CompMap m, Str dis, Str expect)
  {
    // generate id
    id := m.genId

    // create comp (shim for id)
    c := CompObj()
    MCompSpi#id->setConst(c.spi, id)
    c.spi->slots->set("id", id)
    verifySame(c.id, id)
    c.set("dis", dis)

    // add to map
    oldSize := m.size
    m.add(c)
    verifyEq(id.toStr, expect)
    verifySame(m.get(id), c)
    verifyEq(m.size, oldSize+1)

    return c
  }

  Void clearLinks(CompMap m)
  {
    m.each |c| { c.remove("links") }
  }

  Void link(Comp from, Comp to)
  {
    link := Etc.link(from.id, "ignore")
    curLinks := to.get("links") as Links ?: Etc.links(null)
    to.set("links", curLinks.add("ignore", link))
  }

  Void verifyCompMapSort(CompMap m, Comp[] expect)
  {
    m.topologyChanged
    actual := m.topology
    // echo("~~ sort " + expect.join(", ") { it->dis })
    // echo("        " + actual.join(", ") { it->dis })
    verifyEq(actual.isRO, true)
    verifyEq(actual, expect)
  }
}

