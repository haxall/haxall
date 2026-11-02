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
** CompNullLinkBase loads d.a -> e.a, d.methodEcho -> e.b, d.c -> e.c,
** d.c -> e.methodBad1 (which throws), d.c -> f.b and e.c -> f.c.
** Slots a and b are not maybe.
**
@Js
abstract class CompNullLinkBase : AbstractXetoTest
{
  CompSpace? cs
  TestFoo? d
  TestFoo? e
  TestFoo? f

  override Void setup()
  {
    super.setup
    cs = CompSpace(createNamespace(CompTest.loadTestLibs)).install.start
    cs.loadXeto(
      Str<|@root: TestFolder {
             d @d: TestFoo {}
             e @e: TestFoo { links: {
               a: Link { fromRef: @d, fromSlot:"a" }
               b: Link { fromRef: @d, fromSlot:"methodEcho" }
               c: Link { fromRef: @d, fromSlot:"c" }
               methodBad1: Link { fromRef: @d, fromSlot:"c" }
             } }
             f @f: TestFoo { links: {
               b: Link { fromRef: @d, fromSlot:"c" }
               c: Link { fromRef: @e, fromSlot:"c" }
             } }
           }|>)
    d = cs.root->d; e = cs.root->e; f = cs.root->f
    exec
  }

  override Void teardown()
  {
    CompSpace.uninstall
    super.teardown
  }

  ** Run one cycle; an error escaping CompSpace.execute fails the test
  Void exec(|Obj?|? cb := null)
  {
    TestAxonContext(cs.ns).asCur |cx| { cb?.call(null); cs.execute }
  }

  ** Push target node of the link d.fromSlot -> to.toSlot
  FatSlotPushTo? edge(Str fromSlot, Comp to, Str toSlot)
  {
    FatSlotPushTo? x
    ((MCompSpi)d.spi).eachFat |fat, n|
    {
      if (n == fromSlot) fat.eachPushTo |p| { if (p.toComp === to && p.toSlot == toSlot) x = p }
    }
    return x
  }

  ** Failure state of a link as "isFailing,numSuppressed"
  Str state(Str fromSlot, Comp to, Str toSlot)
  {
    x := edge(fromSlot, to, toSlot)
    return "$x.isFailing,$x.numSuppressed"
  }
}

**
** CompNullLinkTest covers null pushed over links and pushes a target
** cannot take
**
@Js
class CompNullLinkTest : CompNullLinkBase
{
  ** A linked slot set to null keeps its links and pushes the null; an
  ** error from one target does not stop the cycle
  Void testNullOverLink()
  {
    exec { d.set("c", "x") }
    verifyEq([e->c, f->b, f->c], Obj?["x", "x", "x"])
    verifyEq(state("c", e, "methodBad1"), "true,0")

    exec { d.set("c", null) }
    verifyEq(d.has("c"), false)
    verifyEq(((MCompSpi)d.spi).isFat("c"), true)
    verifyEq([e["c"], f->b, f["c"]], Obj?[null, "x", null])
    verifyEq(state("c", e, "c"), "false,0")
    verifyEq(state("c", f, "b"), "true,0")

    exec { d.set("c", "y") }
    verifyEq([e->c, f->b, f->c], Obj?["y", "y", "y"])
    verifyEq(state("c", f, "b"), "false,0")
    verifyEq(state("c", e, "methodBad1"), "true,2")
  }

  ** A failing link counts its repeats across a rebuild until it recovers
  Void testFailureState()
  {
    5.times { exec { d.call("methodEcho", null) } }
    verifyEq(state("methodEcho", e, "b"), "true,4")

    before := edge("methodEcho", e, "b")
    f.set("links", Etc.links(null))
    exec { d.call("methodEcho", null) }
    verifyNotSame(edge("methodEcho", e, "b"), before)
    verifyEq(state("methodEcho", e, "b"), "true,5")

    exec { d.call("methodEcho", "ok") }
    verifyEq(e->b, "ok")
    verifyEq(state("methodEcho", e, "b"), "false,0")
  }

  ** An unlinked slot is removed on null; a linked slot that is not maybe
  ** may not be, and setUnchecked null keeps it fat and skips its push
  Void testNotMaybeSource()
  {
    f.set("c", "x")
    f.set("c", null)
    verifyEq(f.has("c"), false)
    verifyEq(((MCompSpi)f.spi).isFat("c"), false)

    exec { d.set("a", "a2") }
    verifyErr(InvalidChangeErr#) { d.set("a", null) }
    exec { d.spi.setUnchecked("a", null) }
    verifyEq(d.has("a"), false)
    verifyEq(((MCompSpi)d.spi).isFat("a"), true)
    verifyEq(e->a, "a2")
    verifyEq(state("a", e, "a"), "true,0")

    exec { d.set("a", "a3") }
    verifyEq(e->a, "a3")
    verifyEq(state("a", e, "a"), "false,0")
  }
}
