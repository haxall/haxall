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

}

