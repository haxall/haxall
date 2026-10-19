//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using concurrent
using xeto
using xetom
using haystack

**
** CompLoopCutRuntimeTest covers loopCut paths that run on the JVM only
**
class CompLoopCutRuntimeTest : AbstractXetoTest
{
  ** The "link" and "setLoopCut" feed calls set and clear a cut; any
  ** loopCut but Marker or false raises and changes nothing
  Void testFeed()
  {
    ns := createNamespace(CompTest.loadTestLibs)
    actor := CompSpaceActor(ActorPool())
    actor.init(CompSpace(ns)).get
    actor.loadXeto(Str<|@root: TestFolder {
                          a @a: TestNumberAdd {}
                          b @b: TestNumberAdd {}
                        }|>).get
    feed(actor, "link", "a", "b", Marker.val)
    feed(actor, "link", "b", "a", false)
    verifyEq(links(ns, actor), "a.in1=false b.in1=true")

    feed(actor, "setLoopCut", "b", "a", Marker.val)
    feed(actor, "setLoopCut", "a", "b", false)
    verifyEq(links(ns, actor), "a.in1=true b.in1=false")

    [null, true, "true", n(1), None.val].each |v|
    {
      verifyErr(ArgErr#) { feed(actor, "setLoopCut", "a", "b", v) }
      if (v != null) verifyErr(ArgErr#) { feed(actor, "link", "a", "b", v, "in2") }
    }
    verifyEq(links(ns, actor), "a.in1=true b.in1=false")
  }

  ** Deferred pushes are delivered in a cycle whose walk throws.  The
  ** throw is a self link pushing null into a dynamic slot.
  Void testDeferredWhenWalkThrows()
  {
    cs := CompSpace(createNamespace(CompTest.loadTestLibs)).install
    try
    {
      cs.loadXeto(Str<|TestFolder {}|>)
      cs.start
      edit := ((MCompSpaceSpi)cs.spi).edit
      p := edit.create(cs.root.id, "hx.test.xeto::TestFoo")
      r := edit.create(cs.root.id, "hx.test.xeto::TestFoo")
      d := edit.create(cs.root.id, "hx.test.xeto::TestFoo")
      r.set("links", r.links.add("b", Etc.linkWrap(Etc.dict3("fromRef", p.id, "fromSlot", "a", "loopCut", Marker.val))))
      d.set("links", d.links.add("b", Etc.link(p.id, "a")).add("foo", Etc.link(d.id, "methodEcho")))
      cx := TestAxonContext(cs.ns)
      cx.asCur |->| { cs.execute; cs.execute }
      d.set("foo", "bar")
      cx.asCur |->|
      {
        p.set("a", "x")
        d.call("methodEcho", null)
        verifyErr(null) { cs.execute }
      }
      verifyEq(r->b, "x")
    }
    finally CompSpace.uninstall
  }

  private Void feed(CompSpaceActor actor, Str type, Str from, Str to, Obj? cut, Str toSlot := "in1")
  {
    req := Str:Obj["type": type, "fromRef": Ref(from), "fromSlot": "out", "toRef": Ref(to), "toSlot": toSlot]
    if (cut != null) req["loopCut"] = cut
    actor.feedCall(Etc.makeDict(req)).get
  }

  ** Links into a and b read back through saveXeto, as "a.in1=<cut>"
  private Str links(Namespace ns, CompSpaceActor actor)
  {
    cs := CompSpace(ns).install
    try
    {
      cs.loadXeto(actor.saveXeto.get)
      acc := Str[,]
      ["a", "b"].each |n|
      {
        cs.readById(Ref(n)).links.eachLink |slot, x| { acc.add("${n}.$slot=" + CompUtil.isLoopCut(x)) }
      }
      return acc.join(" ")
    }
    finally CompSpace.uninstall
  }
}
