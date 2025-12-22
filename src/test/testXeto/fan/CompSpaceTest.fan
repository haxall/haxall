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
    verifyPushTo(a, Str[,])
    verifyPushTo(b, Str[,])
    verifyPushTo(c, Str[,])
    verifyPushTo(d, Str[,])
    verifyPushTo(e, Str[,])
    verifyPushTo(f, Str[,])

    // add some links f -> e -> d -> c -> b -> a
    link(f, e)
    link(e, d)
    link(d, c)
    link(c, b)
    link(b, a)
    verifyCompMapSort(m, [f, e, d, c, b, a])
    verifyPushTo(f, ["out -> E.in"])
    verifyPushTo(e, ["out -> D.in"])
    verifyPushTo(d, ["out -> C.in"])
    verifyPushTo(c, ["out -> B.in"])
    verifyPushTo(b, ["out -> A.in"])

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
    verifyPushTo(a, ["out -> B.in"])
    verifyPushTo(b, ["out -> C.in"])
    verifyPushTo(c, ["out -> D.in"])
    verifyPushTo(e, ["out -> F.in"])
    verifyPushTo(f, ["out -> C.in", "out -> B.in"])

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
    verifyPushTo(a, ["out -> B.in"])
    verifyPushTo(b, ["out -> C.in"])
    verifyPushTo(c, ["out -> A.in"])
    verifyPushTo(d, ["out -> E.in"])
    verifyPushTo(e, ["out -> F.in"])
    verifyPushTo(f, Str[,])

    // remove a and c (leaving broken links)
    m.remove(a)
    m.remove(c)
    verifyCompMapSort(m, [b, d, e, f])
    verifyPushTo(b, Str[,])
    verifyPushTo(d, ["out -> E.in"])
    verifyPushTo(e, ["out -> F.in"])

    // add some back reused
    g := compMapAdd(m, "G", "6")
    h := compMapAdd(m, "H", "7")
    i := compMapAdd(m, "I", "8")
    verifyCompMapSort(m, [b, d, e, f, g, h, i])
    verifyPushTo(b, Str[,])
    verifyPushTo(d, ["out -> E.in"])
    verifyPushTo(e, ["out -> F.in"])
    verifyPushTo(g, Str[,])
    verifyPushTo(h, Str[,])
    verifyPushTo(i, Str[,])

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

  Void link(Comp from, Comp to, Str fromSlot := "out", Str toSlot := "in")
  {
    link := Etc.link(from.id, fromSlot)
    curLinks := to.get("links") as Links ?: Etc.links(null)
    to.set("links", curLinks.add(toSlot, link))
  }

  Void verifyCompMapSort(CompMap m, Comp[] expect)
  {
    m.topologyChanged
    actual := m.topology

    if (false)
    {
      echo
      echo("~~ sort " + expect.join(", ") { it->dis })
      echo("        " + actual.join(", ") { it->dis })
      dumpTopology(m)
    }

    verifyEq(actual.isRO, true)
    verifyEq(actual, expect)
  }

  Void verifyPushTo(Comp c, Str[] expect)
  {
    actual := Str[,]
    spi := (MCompSpi)c.spi
    spi.eachFat |fat, n|
    {
      fat.eachPushTo |x|
      {
        actual.add("$n -> ${x.toComp.dis}.${x.toSlot}")
      }
    }
    verifyEq(actual, expect)
  }

  Void dumpTopology(CompMap m)
  {
    s := StrBuf()
    m.dumpTopology(s.out)
    echo(s.toStr)
  }

//////////////////////////////////////////////////////////////////////////
// Execute
//////////////////////////////////////////////////////////////////////////

 static Str executeTestXeto()
  {
     Str<|@root: TestFolder {
            a @a: TestCounter {
              fooRef: @c
            }
            b @b: TestCounter {
             fooRef: @a
            }
            c @c: TestAdd {
              links: {
                in1: Link { fromRef: @a, fromSlot:"out" }
                in2: Link { fromRef: @b, fromSlot:"out" }
              }
            }
            d @d: TestFoo {
            }
            e @e: TestFoo {
              links: {
                b: Link { fromRef: @d, fromSlot:"a" }
                c: Link { fromRef: @d, fromSlot:"methodUpper" } // method -> field
                methodUpper: Link { fromRef: @d, fromSlot:"methodEcho" } // method -> method
              }
            }
            f @f: TestFoo {
              links: {
                b: Link { fromRef: @e, fromSlot:"b" }
                c: Link { fromRef: @e, fromSlot:"methodUpper" } // method -> field
                methodUpper: Link { fromRef: @d, fromSlot:"c" } // field -> method
              }
            }
            g @g: TestFoo {
              links: {
                c: Link { fromRef: @f, fromSlot:"methodUpper" } // method -> field
              }
            }
          }|>
  }

  Void testExecute()
  {
    ns := createNamespace(CompTest.loadTestLibs)
    cs := CompSpace(ns)
    cs.load(executeTestXeto)

    a := (TestCounter)cs.root->a
    b := (TestCounter)cs.root->b
    c := (TestAdd)cs.root->c
    d := (TestFoo)cs.root->d
    e := (TestFoo)cs.root->e
    f := (TestFoo)cs.root->f
    g := (TestFoo)cs.root->g

    // initial state
    verifyExecuteCounter(a, 0)
    verifyExecuteCounter(b, 0)
    verifyExecuteAdd(c, 0, 0, 0)
    verifyExecuteFoo(d, 0, "alpha", "beta", null)
    verifyExecuteFoo(e, 0, "alpha", "beta", null)
    verifyExecuteFoo(f, 0, "alpha", "beta", null)

    // everything executes on first execute
    ts := DateTime.now - 1day
    execute(cs, ts) {}
    verifyExecuteCounter(a, 1)
    verifyExecuteCounter(b, 1)
    verifyExecuteAdd(c, 1, 1, 2)
    verifyExecuteFoo(d, 1, "alpha", "beta", null)
    verifyExecuteFoo(e, 1, "alpha", "alpha", null)
    verifyExecuteFoo(f, 1, "alpha", "alpha", null)

    // - counters don't trip yet at 59sec;
    // - field set d.a -> e.b -> f.b
    // - method to field: d.methodUpper -> e.c
    // - method to method to field: d.methodEcho -> e.methodUpper -> f.c
    d.set("a", "wow!")
    execute(cs, ts + 59sec)
    {
      d.call("methodEcho", "woot!")
      d.call("methodUpper", "foo bar")
    }
    verifyExecuteCounter(a, 1)
    verifyExecuteCounter(b, 1)
    verifyExecuteAdd(c, 1, 1, 2)
    verifyExecuteFoo(d, 2, "wow!", "beta", null)
    verifyExecuteFoo(e, 2, "alpha", "wow!", "FOO BAR")
    verifyExecuteFoo(f, 2, "alpha", "wow!", "WOOT!")

    // - execute +1min; counters trigger once
    // - verify TestFoo do not execute
    d.set("a", "wow!")
    execute(cs, ts + 1min) {}
    verifyExecuteCounter(a, 2)
    verifyExecuteCounter(b, 2)
    verifyExecuteAdd(c, 2, 2, 4)
    verifyExecuteFoo(d, 2, "wow!", "beta", null)
    verifyExecuteFoo(e, 2, "alpha", "wow!", "FOO BAR")
    verifyExecuteFoo(f, 2, "alpha", "wow!", "WOOT!")

    // - execute +2min; counters trigger twice
    // - verify methodEcho with null
    execute(cs, ts + 2min)
    {
      d.call("methodEcho", null)
    }
    verifyExecuteCounter(a, 3)
    verifyExecuteCounter(b, 3)
    verifyExecuteAdd(c, 3, 3, 6)
    verifyExecuteFoo(d, 2, "wow!", "beta", null)
    verifyExecuteFoo(e, 2, "alpha", "wow!", "FOO BAR")
    verifyExecuteFoo(f, 3, "alpha", "wow!", "NULL")

    // - verify field -> method
    d.set("c", "field->method")
    execute(cs, ts + 2min) {}
    verifyExecuteCounter(a, 3)
    verifyExecuteCounter(b, 3)
    verifyExecuteAdd(c, 3, 3, 6)
    verifyExecuteFoo(d, 3, "wow!", "beta", "field->method")
    verifyExecuteFoo(e, 2, "alpha", "wow!", "FOO BAR")
    verifyExecuteFoo(f, 3, "alpha", "wow!", "NULL")
    verifyExecuteFoo(g, 2, "alpha", "beta", "FIELD->METHOD")
  }

  Void execute(CompSpace cs, DateTime now, |This| cb)
  {
    TestAxonContext(cs.ns).asCur |cx|
    {
      cb(this)
      cx.now = now
      cs.execute
    }
  }

  Void verifyExecuteCounter(TestCounter c, Int out)
  {
    verifyEq(c["out"], TestVal(out))
  }

  Void verifyExecuteAdd(TestAdd c, Int in1, Int in2, Int out)
  {
    verifyEq(c["in1"], TestVal(in1))
    verifyEq(c["in2"], TestVal(in2))
    verifyEq(c["out"], TestVal(out))
  }

  Void verifyExecuteFoo(TestFoo x, Int numExecutes, Str a, Str b, Str? c)
  {
    // echo(">> $x.name $x.numExecutes"); x.dump
    verifyEq(x.numExecutes, numExecutes)
    verifyEq(x["a"], a)
    verifyEq(x["b"], b)
    verifyEq(x["c"], c)
  }
}

