//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Dec 2023  Brian Frank  Creation
//

using concurrent
using xeto
using xetoEnv
using haystack

**
** CheckTest
**
@Js
class CompTest: AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Test
//////////////////////////////////////////////////////////////////////////

  CompSpace? cs

  override Void setup()
  {
    super.setup

    ns := createNamespace(["hx.test.xeto"])
    ns.lib("hx.test.xeto")
    cs = CompSpace(ns).initRoot { CompObj() }
    Actor.locals[CompSpace.actorKey] = cs
  }

  override Void teardown()
  {
    super.teardown
    Actor.locals.remove(CompSpace.actorKey)
  }

//////////////////////////////////////////////////////////////////////////
// Instantiation
//////////////////////////////////////////////////////////////////////////

  Void testInstantiation()
  {
    composite := cs.ns.spec("hx.test.xeto::TestComposite")
    add       := cs.ns.spec("hx.test.xeto::TestAdd")

    // create composite comp
    c    := CompObj(composite)
    a    := (Comp)c->a
    nest := (Comp)c->nest
    b    := (Comp)nest->b
    verifySame(c["spec"], composite._id)
    verifyEq(c["descr"], "test descr")
    verifyEq(c["dur"], 5min)
    verifyCompEq(c, ["dis":"TestComposite", "id":c.id,
      "spec":composite._id, "descr":"test descr", "dur":5min,
      "a":a, "nest":nest])

    // verify it created a (one level child)
    verifySame(a.parent, c)
    verifyEq(a.name, "a")
    verifySame(c.child("a"), a)
    verifyCompEq(a, ["dis":"a", "id":a.id,
      "spec":add._id, "in1":n(7), "in2":n(5), "out":n(0)])

    // verify it created b (two level child)
    verifySame(nest.parent, c)
    verifySame(b.parent, nest)
    verifyEq(b.name, "b")
    verifySame(c.child("nest"), nest)
    verifySame(nest.child("b"), b)
    verifyCompEq(b, ["dis":"b", "id":b.id,
      "spec":add._id, "in1":n(17), "in2":n(15), "out":n(0)])

    // verify unmounted
    verifyEq(c.name, "")
    verifyEq(c.parent, null)
    verifyEq(c.isMounted, false)
    verifyEq(a.isMounted, false)
    verifyEq(b.isMounted, false)
    verifyEq(cs.readById(c.id, false), null)
    verifyEq(cs.readById(a.id, false), null)
    verifyEq(cs.readById(b.id, false), null)

    // verify recursive mount
    cs.root["composite"] = c
    verifyEq(c.name, "composite")
    verifyEq(c.parent, cs.root)
    verifySame(cs.root->composite, c)
    verifyEq(c.isMounted, true)
    verifyEq(a.isMounted, true)
    verifyEq(b.isMounted, true)
    verifySame(cs.readById(c.id, false), c)
    verifySame(cs.readById(a.id, false), a)
    verifySame(cs.readById(b.id, false), b)
  }

//////////////////////////////////////////////////////////////////////////
// Tree
//////////////////////////////////////////////////////////////////////////

  Void testTree()
  {
    ns := createNamespace(["hx.test.xeto"])
    folder := ns.spec("hx.test.xeto::TestFolder")
    add := ns.spec("hx.test.xeto::TestAdd")
    cs := CompSpace(ns).initRoot { CompObj(folder) }
    Actor.locals[CompSpace.actorKey] = cs
    r := cs.root

    verifyTree(cs, "", null, r, [,])

    // add "a"
    a := CompObj(folder); r.add(a, "a")
    verifyTree(cs, "",  null, r, [a])
    verifyTree(cs, "a", r,    a, [,])

    // add "a.b"
    b := CompObj(add); a.add(b, "b")
    verifyTree(cs, "",    null, r, [a])
    verifyTree(cs, "a",   r,    a, [b])
    verifyTree(cs, "a.b", a,    b, [,])

    // add "a.c"
    c := CompObj(add); a.set("c", c)
    verifyTree(cs, "",    null, r, [a])
    verifyTree(cs, "a",   r,    a, [b, c])
    verifyTree(cs, "a.b", a,    b, [,])
    verifyTree(cs, "a.c", a,    c, [,])

    // build mini-graph, then add
    d := CompObj(folder)                 // a.d
    e := CompObj(add);    d.add(e, "e")  // a.d.e
    f := CompObj(folder); d.set("f", f)  // a.d.f
    g := CompObj(add);    f.add(g, "g")  // a.d.f.g
    a["d"] = d
    verifyTree(cs, "",        null, r, [a])
    verifyTree(cs, "a",       r,    a, [b, c, d])
    verifyTree(cs, "a.b",     a,    b, [,])
    verifyTree(cs, "a.c",     a,    c, [,])
    verifyTree(cs, "a.d",     a,    d, [e, f])
    verifyTree(cs, "a.d.e",   d,    e, [,])
    verifyTree(cs, "a.d.f",   d,    f, [g])
    verifyTree(cs, "a.d.f.g", f,    g, [,])

    // remove d
    verifyEq(d.name, "d");  verifyEq(d.parent, a)
    a.remove("d")
    verifyEq(d.name, "");   verifyEq(d.parent, null)
    verifyEq(e.parent, d);  verifyEq(e.name, "e")
    verifyEq(cs.readById(d.id, false), null)
    verifyEq(cs.readById(e.id, false), null)
    verifyEq(cs.readById(f.id, false), null)
    verifyEq(cs.readById(g.id, false), null)
    verifyTree(cs, "",        null, r, [a])
    verifyTree(cs, "a",       r,    a, [b, c])
    verifyTree(cs, "a.b",     a,    b, [,])
    verifyTree(cs, "a.c",     a,    c, [,])

    // now add d back
    a.add(d, "d")
    verifyTree(cs, "",        null, r, [a])
    verifyTree(cs, "a",       r,    a, [b, c, d])
    verifyTree(cs, "a.b",     a,    b, [,])
    verifyTree(cs, "a.c",     a,    c, [,])
    verifyTree(cs, "a.d",     a,    d, [e, f])
    verifyTree(cs, "a.d.e",   d,    e, [,])
    verifyTree(cs, "a.d.f",   d,    f, [g])
    verifyTree(cs, "a.d.f.g", f,    g, [,])

    // isAbove
    verifyEq(r.isAbove(r), true)
    verifyEq(r.isAbove(a), true)
    verifyEq(r.isAbove(b), true)
    verifyEq(r.isAbove(d), true)
    verifyEq(r.isAbove(e), true)
    verifyEq(r.isAbove(f), true)
    verifyEq(r.isAbove(g), true)
    verifyEq(a.isAbove(r), false)
    verifyEq(b.isAbove(r), false)
    verifyEq(d.isAbove(r), false)
    verifyEq(e.isAbove(r), false)
    verifyEq(f.isAbove(r), false)
    verifyEq(f.isAbove(a), false)

    // isBelow
    verifyEq(g.isBelow(g), true)
    verifyEq(g.isBelow(f), true)
    verifyEq(g.isBelow(d), true)
    verifyEq(g.isBelow(a), true)
    verifyEq(g.isBelow(r), true)
    verifyEq(g.isBelow(b), false)
    verifyEq(r.isBelow(b), false)
    verifyEq(a.isBelow(g), false)

    // cleanup
    Actor.locals.remove(CompSpace.actorKey)
  }

  Void verifyTree(CompSpace cs, Str path, Comp? parent, Comp c, Comp[] children)
  {
    // echo("~~ verifyTree $path")

    // lookup comp by path string
    x := cs.root
    verifyEq(x.name, "")
    isRoot := path.isEmpty
    if (!isRoot)
    {
      path.split('.').each |n|
      {
        x = (Comp)x.get(n) as Comp ?: throw Err("$x missing $n")
        verifyEq(x.name, n)
      }
    }
    verifySame(x, c)

    // mounted
    verifyEq(x.isMounted, true)
    verifySame(cs.readById(x.id), x)

    // parent
    verifySame(x.parent, parent)

    // children
    kids := Comp[,]
    x.eachChild |kid, n|
    {
      verifyEq(x.hasChild(n), true)
      verifySame(x.child(n), kid)
      kids.add(kid)

      verifyEq(x.isAbove(kid), true)
      verifyEq(kid.isAbove(x), false)
      verifyEq(kid.isBelow(x), true)
      verifyEq(x.isBelow(kid), false)
    }
    verifyEq(kids.size, children.size)
    kids.each |kid, i| { verifySame(kid, children[i]) }

    // each
    x.each |v, n|
    {
      if (v is Comp)
      {
        verifyEq(x.hasChild(n), true)
        verifyEq(kids.containsSame(v), true)
      }
      else
      {
        verifyEq(x.hasChild(n), false)
      }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Methods
//////////////////////////////////////////////////////////////////////////

  Void testMethods()
  {
    c := TestFoo()
    verifyEq(c.spec.qname, "hx.test.xeto::TestFoo")
    verifyEq(c.has("method1"), true)
    verifyEq(c.has("method2"), true)
    verifyEq(c.has("method3"), true)
    verifyEq(c.has("methodUnsafe"), false)
    verifyEq(c.get("method1").typeof, FantomMethodCompFunc#)
    verifyEq(c.get("method2").typeof, FantomMethodCompFunc#)
    verifyEq(c.get("method3").typeof, FantomMethodCompFunc#)
    verifyEq(c.get("methodUnsafe"), null)

    // slot not defined
    verifyEq(c.call("notFound"), null)
    verifyEq(c.call("notFound", null), null)
    verifyEq(c["last"], null)

    // method1 call
    c.remove("last")
    verifyEq(c.call("method1", "one"), null)
    verifyEq(c["last"], "one")

    // method2
    verifyEq(c.call("method2"), "method2 called")
    c.remove("last")
    verifyEq(c.call("method2", "two"), "method2 called")
    verifyEq(c["last"], "_method2_")

    // method3
    c.remove("last")
    verifyEq(c.call("method3", "three"), "method3 called: three")
    verifyEq(c["last"], "three")

    // methodUnsafe - since its not in spec, cannot reflect
    c.remove("last")
    verifyEq(c.call("methodUnsafe", "no-way"), null)
    verifyEq(c["last"], null)

    // now override method3
    c.setFunc("method3") |self, arg| { "method3 override: $arg" }
    c.remove("last")
    verifyEq(c.call("method3", "by func"), "method3 override: by func")
    verifyEq(c["last"], null)

    // remove method3 override, which falls back to reflected method
    c.remove("last")
    verifyEq(c.has("method3"), true)
    verifyEq(c.get("method3").typeof, FantomFuncCompFunc#)
    c.remove("method3")
    verifyEq(c.has("method3"), true)
    verifyEq(c.get("method3").typeof, FantomMethodCompFunc#)
    verifyEq(c.call("method3", "reflect again"), "method3 called: reflect again")
    verifyEq(c["last"], "reflect again")
  }

//////////////////////////////////////////////////////////////////////////
// Callbacks
//////////////////////////////////////////////////////////////////////////

  Void testCallbacks()
  {
    c := TestFoo()
    verifyEq(c.get("a"), "alpha")
    verifyEq(c.get("b"), "beta")

    debug := |s| {} //echo(s) }

    // listener
    a1 := null
    acb1 := |self, v| { a1 = v; debug("a1=$v") }
    c.onChange("a", acb1)
    c.set("a", "1")
    verifyEq(a1, "1")
    verifyEq(c.onChangeThisLast, "a = 1")

    // remove with wrong name
    c.onChangeRemove("foo", acb1)
    c.set("a", "2")
    verifyEq(a1, "2")

    // remove with correct name
    c.onChangeRemove("a", acb1)
    c.set("a", "3")
    verifyEq(a1, "2")

    // now add a few
    a2 := null; acb2 := |self, v| { a2 = v; debug("a2=$v") }
    a3 := null; acb3 := |self, v| { a3 = v; debug("a3=$v") }
    a4 := null; acb4 := |self, v| { a4 = v; debug("a4=$v") }
    c.onChange("a", acb1)
    c.onChange("a", acb2)
    c.onChange("a", acb3)
    c.onChange("a", acb4)
    c.set("a", "4")
    verifyEq(a1, "4")
    verifyEq(a2, "4")
    verifyEq(a3, "4")
    verifyEq(a4, "4")

    // remove head
    c.onChangeRemove("a", acb1)
    c.set("a", "5")
    verifyEq(a1, "4")
    verifyEq(a2, "5")
    verifyEq(a3, "5")
    verifyEq(a4, "5")

    // remove middle
    c.onChangeRemove("a", acb3)
    c.set("a", "6")
    verifyEq(a1, "4")
    verifyEq(a2, "6")
    verifyEq(a3, "5")
    verifyEq(a4, "6")

    // remove tail
    c.onChangeRemove("a", acb4)
    c.set("a", "7")
    verifyEq(a1, "4")
    verifyEq(a2, "7")
    verifyEq(a3, "5")
    verifyEq(a4, "6")
    verifyEq(c.onChangeThisLast, "a = 7")

    // remove last one
    c.onChangeRemove("a", acb2)
    c.set("a", "8")
    verifyEq(a1, "4")
    verifyEq(a2, "7")
    verifyEq(a3, "5")
    verifyEq(a4, "6")
    verifyEq(c.onChangeThisLast, "a = 8")

    // register onChange and onCall on method3
    mx1 := null; mx1cb := |self, v| { mx1 = v; debug("mx1=$v") }
    mc1 := null; mc1cb := |self, v| { mc1 = v; debug("mc1=$v") }
    c.onChange("method3", mc1cb)
    c.onCall("method3", mx1cb)
    c.call("method3", "100")
    verifyEq(mc1, null)
    verifyEq(mx1, "100")
    verifyEq(c.onCallThisLast, "method3 = 100")

    // add some more onCall
    mx2 := null; mx2cb := |self, v| { mx2 = v; debug("mx2=$v") }
    mx3 := null; mx3cb := |self, v| { mx3 = v; debug("mx3=$v") }
    c.onCall("method3", mx2cb)
    c.onCall("method3", mx3cb)
    c.call("method3", "200")
    verifyEq(mc1, null)
    verifyEq(mx1, "200")
    verifyEq(mx2, "200")
    verifyEq(mx3, "200")

    // change method3
    c.setFunc("method3") |arg| { "override=$arg" }
    verifyEq(mc1 is FantomFuncCompFunc, true)
    verifyEq(mx1, "200")
    verifyEq(mx2, "200")
    verifyEq(mx3, "200")
    c.call("method3", "300")
    verifyEq(mc1 is FantomFuncCompFunc, true)
    verifyEq(mx1, "300")
    verifyEq(mx2, "300")
    verifyEq(mx3, "300")

    // remove change method3
    mc1 = null
    c.onChangeRemove("method3", mc1cb)
    c.set("method3", null)
    c.call("method3", "400")
    verifyEq(mc1, null)
    verifyEq(mx1, "400")
    verifyEq(mx2, "400")
    verifyEq(mx3, "400")

    // remove method3 onCalls...
    c.onCallRemove("method3", mx2cb)
    c.call("method3", "500")
    verifyEq(mc1, null)
    verifyEq(mx1, "500")
    verifyEq(mx2, "400")
    verifyEq(mx3, "500")
    c.onCallRemove("method3", mx3cb)
    c.call("method3", "600")
    verifyEq(mc1, null)
    verifyEq(mx1, "600")
    verifyEq(mx2, "400")
    verifyEq(mx3, "500")
    c.onCallRemove("method3", mx1cb)
    c.call("method3", "700")
    verifyEq(mc1, null)
    verifyEq(mx1, "600")
    verifyEq(mx2, "400")
    verifyEq(mx3, "500")

    // register onChange for slot not added yet
    n := null
    c.onChange("newone") |self, v| { n = v }
    c.set("newone", "1st")
    verifyEq(n, "1st")
    c.set("newone", null)
    verifyEq(n, null)
    c.add("2nd", "newone")
    verifyEq(n, "2nd")
    c.remove("newone")
    verifyEq(n, null)
  }

//////////////////////////////////////////////////////////////////////////
// Load/Save
//////////////////////////////////////////////////////////////////////////

  Void testLoad()
  {
    xeto :=
     Str<|@root: TestFolder {
            b @b: TestRamp { }
            c @add: TestAdd {
              links: {
                Link { fromRef: @a, fromSlot:"out", toSlot:"in1" }
                Link { fromRef: @b, fromSlot:"out", toSlot:"in2" }
              }
            }
            a @a: TestRamp {
              fooRef: @add
            }
          }|>

    ns := createNamespace(["sys.comp", "hx.test.xeto"])
    cs := CompSpace(ns)
    cs.load(xeto)

cs.root.dump

    r := verifyLoadComp(cs, cs.root, "",  null, "TestFolder")
    a := verifyLoadComp(cs, r->a,    "a", r,    "TestRamp")
    b := verifyLoadComp(cs, r->b,    "b", r,    "TestRamp")
    c := verifyLoadComp(cs, r->c,    "c", r,    "TestAdd")

    // verify ref swizzling
    verifyEq(a->fooRef, c.id)

    verifyLoadLink(a, "out", r, "in1")
    verifyLoadLink(b, "out", r, "in2")
  }

  Comp verifyLoadComp(CompSpace cs, Comp c, Str name, Comp? parent, Str specName)
  {
echo("verifLoad $c")
    verifyEq(c.name, name)
    verifyEq(c.spec.name, specName)
    verifyEq(c.isMounted, true)
    verifySame(c.parent, parent)
    verifySame(cs.readById(c.id), c)
    return c
  }

  Void verifyLoadLink(Comp f, Str fs, Comp t, Str ts)
  {
    links := t.links
echo("verifyLink $f $fs => $t $ts | $links.list")
  }

}

**************************************************************************
** TestFoo
**************************************************************************

@Js
class TestFoo : CompObj
{
  private Void onMethod1(Str s)
  {
    set("last", s)
  }

  private Str onMethod2()
  {
    set("last", "_method2_")
    return "method2 called"
  }

  private Str onMethod3(Str s)
  {
    set("last", s)
    return "method3 called: $s"
  }

  private Str onMethodUnsafe(Str s)
  {
    // this method isn't in the spec, so can't be called via reflection
    set("last", s)
    return "methodUnsafe called: $s"
  }

  Str? onChangeThisLast
  Str? onCallThisLast

  override Void onCallThis(Str n, Obj? v)
  {
    onCallThisLast = "$n = $v"
  }

  override Void onChangeThis(Str n, Obj? v)
  {
    onChangeThisLast = "$n = $v"
  }
}

