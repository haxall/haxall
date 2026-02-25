//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Dec 2023  Brian Frank  Creation
//

using concurrent
using xeto
using xeto::Comp
using xetom
using haystack
using axon

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
// Updates
//////////////////////////////////////////////////////////////////////////

  Void testUpdates()
  {
    c := TestFoo()
    spi := (MCompSpi)c.spi

    // initial state
    verifyEq(c["id"], c.id)
    verifyEq(c.spec.name, "TestFoo")
    verifyEq(c.get("a"), "alpha")
    verifyEq(c.get("b"), "beta")
    verifyEq(c.get("c"), null)
    verifyEq(c.has("b"), true)
    verifyEq(c.missing("b"), false)
    verifyEq(c.hasMethod("b"), false)

    // not found
    verifyEq(c.has("notFound"), false)
    verifyEq(c.missing("notFound"), true)
    verifyEq(c.hasMethod("notFound"), false)
    verifyEq(c.get("notFound"), null)

    // set as update
    c.reset.set("b", "change it")
    verifySame(c.get("b"), "change it")
    verifyChanged(c, "b", "change it")

    // set short circuit
    c.reset.set("b", "change it")
    verifyNotChanged(c)

    // fatten b
    verifyEq(spi.isFat("b"), false)
    fat := spi.fatten("b")
    verifyEq(spi.isFat("b"), true)
    verifyEq(c.get("b"), "change it")
    verifyEq(c.has("b"), true)
    verifyEq(c.missing("b"), false)
    c.reset.set("b", "change it")
    verifyNotChanged(c)
    verifyEq(c.get("b"), "change it")
    c.reset.set("b", "bravo!")
    verifyChanged(c, "b", "bravo!")
    verifyEq(spi.isFat("b"), true)
    verifySame(spi.fatten("b"), fat)

    // set as add
    num := n(123)
    c.reset.set("foo", num)
    verifySame(c.get("foo"), num)
    verifyChanged(c, "foo", num)

    // set short circuit
    c.reset.set("foo", num)
    verifyNotChanged(c)

    // set as remove
    c.reset.set("foo", null)
    verifyEq(c.get("foo"), null)
    verifyChanged(c, "foo", null)

    // add with name
    c.reset.add(num, "bar")
    verifySame(c.get("bar"), num)
    verifyChanged(c, "bar", num)

    // add without name
    c.reset.add("auto")
    verifySame(c.get("_0"), "auto")
    verifyChanged(c, "_0", "auto")

    // each
    expect := ["id":c.id, "spec":c.spec.id, "dis":"TestFoo", "a":"alpha",
      "b":"bravo!", "bar":n(123), "_0":"auto"]
    map := Str:Obj?[:] { ordered = true }
    c.each |v, n| { map[n] = v }
    verifyEq(map, expect)

    // eachWhile
    map.clear
    c.eachWhile |v, n| { map[n] = v; return null }
    verifyEq(map, expect)

    // remove
    c.remove("_0")
    verifySame(c.get("_0"), null)
    verifyChanged(c, "_0", null)

    // remove with maybe
    c.set("c", "charlie")
    verifySame(c.get("c"), "charlie")
    c.remove("c")
    verifySame(c.get("c"), null)
    verifyChanged(c, "c", null)

    // reorder
    names := Str[,]
    c.each |v, n| { names.add(n) }
    names.swap(-1, -2)
    c.reset.reorder(names)
    verifyChanged(c, "reorder!", null)

    // cannot update const slots
    verifyChangeErr { c.set("id", Ref.gen) }
    verifyChangeErr { c.set("spec", c.spec) }
    verifyChangeErr { c.remove("id") }
    verifyChangeErr { c.remove("spec") }
    verifyDupNameErr { c.add(Ref.gen, "id") }
    verifyDupNameErr { c.add(c.spec, "spec") }

    // cannot set mutable values
    verifyMutErr { c.set("bad", this) }
    verifyMutErr { c.add(this) }

    // cannot remove non-maybe slots
    verifyChangeErr { c.set("a", null) }
    verifyChangeErr { c.remove("a") }

    // cannot set/add with invalid slot name
    verifyNameErr { c.set("bad name", "boo") }
    verifyNameErr { c.add("boo", "bad name") }
  }

  Void verifyChangeErr(|This| f) { verifyErr(InvalidChangeErr#, f) }

  Void verifyDupNameErr(|This| f) { verifyErr(DuplicateNameErr#, f) }

  Void verifyMutErr(|This| f) { verifyErr(NotImmutableErr#, f) }

  Void verifyNameErr(|This| f) { verifyErr(InvalidNameErr#, f) }

  Void verifyChanged(TestFoo c, Str n, Obj? v)
  {
    // echo("  ~~ changed? $c.changeName = $c.changeVal")
    verifyEq(c.change.name, n)
    verifySame(c.change.newVal, v)
    verifySame(c.change.slot, c.spec.slot(n, false))
  }

  Void verifyNotChanged(TestFoo c)
  {
    verifyEq(c.change, null)
  }

//////////////////////////////////////////////////////////////////////////
// Instantiation
//////////////////////////////////////////////////////////////////////////

  Void testInstantiation()
  {
    composite := cs.ns.spec("hx.test.xeto::TestComposite")
    addSpec   := cs.ns.spec("hx.test.xeto::TestAdd")

    verifyEq(cs.ns.spec("sys::Str").isComp, false)
    verifyEq(cs.ns.spec("sys::Dict").isComp, false)
    verifyEq(composite.isComp, true)
    verifyEq(addSpec.isComp, true)

    // create empty add
    TestAdd add := cs.createSpec(addSpec)
    verifyEq(add["spec"], addSpec.id)
    verifyEq(add["in1"], TestVal(0, ""))
    verifyEq(add["in2"], TestVal(0, ""))
    verifyEq(add["out"], TestVal(0, ""))

    // create composite comp
    c    := CompObj(composite)
    a    := (Comp)c->a
    nest := (Comp)c->nest
    b    := (Comp)nest->b
    verifySame(c["spec"], composite.id)
    verifyEq(c["descr"], "test descr")
    verifyEq(c["dur"], 5min)
    verifyCompEq(c, ["dis":"TestComposite", "id":c.id,
      "spec":composite.id, "descr":"test descr", "dur":5min,
      "a":a, "nest":nest])

    // verify it created a (one level child)
    verifySame(a.parent, c)
    verifyEq(a.name, "a")
    verifySame(c.child("a"), a)
    verifyCompEq(a, ["dis":"TestAdd", "id":a.id,
      "spec":addSpec.id, "in1":TestVal(7), "in2":TestVal(5), "out":TestVal(0)])

    // verify it created b (two level child)
    verifySame(nest.parent, c)
    verifySame(b.parent, nest)
    verifyEq(b.name, "b")
    verifySame(c.child("nest"), nest)
    verifySame(nest.child("b"), b)
    verifyCompEq(b, ["dis":"TestAdd", "id":b.id,
      "spec":addSpec.id, "in1":TestVal(17), "in2":TestVal(15), "out":TestVal(0)])

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
    verifyMethod(c, "methodEcho",   "foo", "foo")
    verifyMethod(c, "methodEcho",   n(123), n(123))
    verifyMethod(c, "methodSquare", n(2), n(4))
    verifyMethod(c, "methodUpper", "hi", "HI")
    verifyMethod(c, "methodThis", "ignore", c)

    // verify bad fantom methods
    verifyInvalidMethod(c, "methodBad1", "Comp method missing @Api facet: testXeto::TestFoo.onMethodBad1")
    verifyInvalidMethod(c, "methodBad2", "Comp method must not be static: testXeto::TestFoo.onMethodBad2")
    verifyInvalidMethod(c, "methodBad3", "Comp method must have exactly one param: testXeto::TestFoo.onMethodBad3")
    verifyInvalidMethod(c, "methodBad4", "Comp method must have exactly one param: testXeto::TestFoo.onMethodBad4")

    // verify methods not found
    verifyUnknownMethod(c, "notFound")

    // verify calling non-method slot
    verifyNotMethod(c, "a", "Spec is not func: hx.test.xeto::TestFoo.a")

    // fatten a slot and verify
    spi := (MCompSpi)c.spi
    verifyEq(spi.isFat("methodEcho"), false)
    fat := spi.fatten("methodEcho")
    verifyEq(spi.isFat("methodEcho"), true)
    verifySame(spi.fatten("methodEcho"), fat)
    verifyMethod(c, "methodEcho",   n(123), n(123))

    // verify reorder ignores fat methods
    names := Str[,]
    c.each |v, n| { names.add(n) }
    names.swap(-1, -2)
    c.reorder(names)
    newNames := Str[,]
    c.each |v, n| { newNames.add(n) }
    verifyEq(newNames, names)
    verifyEq(spi.isFat("methodEcho"), true)
  }

  Void verifyMethod(Comp c, Str name, Obj? arg, Obj? expect)
  {
    verifyEq(c.spec.slot(name).isFunc, true)

    // verify no value for get, has, missing
    verifyEq(c.get(name), null)
    verifyEq(c.has(name), false)
    verifyEq(c.missing(name), true)
    verifyEq(c.hasMethod(name), true)

    // verify method not in each
    names := Str[,]
    c.each |v, n| { names.add(n) }
    verifyEq(names.contains(name), false)

    // verify method not in eachWhile
    names.clear
    c.eachWhile |v, n| { names.add(n); return null }
    verifyEq(names.contains(name), false)

    // verify call
    cx := Type.find("testAxon::TestContext").make([this])
    Actor.locals[AxonContext.actorLocalsKey] = cx

    actual := c.call(name, arg)
    verifyEq(actual, expect)

    Actor.locals.remove(AxonContext.actorLocalsKey)
  }

  Void verifyUnknownMethod(Comp c, Str name)
  {
    verifyEq(c.spec.slot(name, false), null)
    verifyErr(UnknownSpecErr#) { c.call(name, false) }
  }

  Void verifyNotMethod(Comp c, Str name, Str msg)
  {
    verifyEq(c.spec.slot(name).isFunc, false)
    verifyErrMsg(UnsupportedErr#, msg) { c.call(name, false) }
  }

  Void verifyInvalidMethod(Comp c, Str name, Str expect)
  {
    verifyErrMsg(Err#, expect) { c.call(name, null) }
  }

//////////////////////////////////////////////////////////////////////////
// Ver
//////////////////////////////////////////////////////////////////////////

  Void testVer()
  {
    r := cs.root
    x := CompObj()
    y := CompObj()
    z := CompObj()

    // dump := |Str s| { echo("$s | cs=$cs.ver r=$r.spi.ver x=$x.spi.ver y=$y.spi.ver z=$z.spi.ver") }

    // initial state
    verifyEq(cs.ver, 1)
    verifyEq(r.spi.ver, 1)
    verifyEq(x.spi.ver, 0)

    // until x mounted no ver changes
    x.set("foo", "bar")
    verifyEq(x.spi.ver, 0)

    // mount x
    r.set("x", x)
    verifyEq(cs.ver, 3)
    verifyEq(r.spi.ver, 3)
    verifyEq(x.spi.ver, 2)

    // set x
    x.set("foo", "new foo")
    verifyEq(cs.ver, 4)
    verifyEq(r.spi.ver, 3)
    verifyEq(x.spi.ver, 4)

    // add x
    x.add("there", "baz")
    verifyEq(cs.ver, 5)
    verifyEq(r.spi.ver, 3)
    verifyEq(x.spi.ver, 5)

    // reorder
    verifyOrder(x, "id, spec, dis, foo, baz")
    x.reorder(["id", "spec", "dis", "baz", "foo"])
    verifyOrder(x, "id, spec, dis, baz, foo")
    verifyEq(x.spi.ver, 6)

    // remove x
    x.remove("baz")
    verifyEq(cs.ver, 7)
    verifyEq(r.spi.ver, 3)
    verifyEq(x.spi.ver, 7)
    verifyEq(y.spi.ver, 0)
    verifyEq(z.spi.ver, 0)

    // mount two comps
    y.set("z", z)
    x.add(y)
    verifyEq(cs.ver, 10)
    verifyEq(r.spi.ver, 3)
    verifyEq(x.spi.ver, 10)
    verifyEq(y.spi.ver, 8)
    verifyEq(z.spi.ver, 9)

    // unmount two comps
    x.set(y.name, "replaced")
    verifyEq(cs.ver, 13)
    verifyEq(r.spi.ver, 3)
    verifyEq(x.spi.ver, 13)
    verifyEq(y.spi.ver, 11)
    verifyEq(z.spi.ver, 12)
  }

//////////////////////////////////////////////////////////////////////////
// Reorder
//////////////////////////////////////////////////////////////////////////

  Void testReorder()
  {
    c := TestAdd()
    fixed := ["id", "spec", "dis", "in1", "in2", "out"]
    verifyOrder(c, fixed.join(", "))

    c.set("a", n(1))
    c.set("b", n(2))
    cur := fixed.dup.add("a").add("b")
    verifyOrder(c, cur.join(", "))

    // must have exact match of names
    verifyErr(ArgErr#) { c.reorder(cur.dup { it.removeAt(-1) }) }
    verifyErr(ArgErr#) { c.reorder(cur.dup { it.set(-1, "x") }) }

    // reorder
    cur.swap(-1, -2)
    c.reorder(cur)
    verifyOrder(c, cur.join(", "))
  }

  Void verifyOrder(Comp c, Str expect)
  {
    s := StrBuf()
    c.each |v, n| { s.join(n, ", ") }
    // echo("~~ $s")
    verifyEq(s.toStr, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Load/Save
//////////////////////////////////////////////////////////////////////////

  static Str[] loadTestLibs()
  {
    ["sys.comp", "hx.test.xeto"]
  }

  static Str loadTestXeto()
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
          }|>
  }

  Void testLoad()
  {
    // fixed Xeto
    cs := doTestLoad(loadTestXeto)

    // test save and round-trip
    saved := cs.save
    doTestLoad(saved)
  }

  CompSpace doTestLoad(Str xeto)
  {
    ns := createNamespace(loadTestLibs)
    cs := CompSpace(ns)
    cs.load(xeto)

    r := verifyLoadComp(cs, cs.root, "",  null, "TestFolder")
    a := verifyLoadComp(cs, r->a,    "a", r,    "TestCounter")
    b := verifyLoadComp(cs, r->b,    "b", r,    "TestCounter")
    c := verifyLoadComp(cs, r->c,    "c", r,    "TestAdd")

    // verify ref swizzling (forward and backward refs)
    verifyEq(a->fooRef, c.id)
    verifyEq(b->fooRef, a.id)

    verifyLoadLink(a, "out", c, "in1")
    verifyLoadLink(b, "out", c, "in2")

    return cs
  }

  Comp verifyLoadComp(CompSpace cs, Comp c, Str name, Comp? parent, Str specName)
  {
    verifyEq(c.name, name)
    verifyEq(c.spec.name, specName)
    verifyEq(c.isMounted, true)
    verifySame(c.parent, parent)
    verifySame(cs.readById(c.id), c)
    return c
  }

  Void verifyLoadLink(Comp f, Str fs, Comp t, Str ts)
  {
    verifySame(t.links, t.links)
    verifySame(t.get("links"), t.links)
    x := t.links.listOn(ts).first ?: throw Err("Failed to find link: $f $fs => $t")
    verifyEq(x.fromRef, f.id)
    verifyEq(x.fromSlot, fs)
  }

}

**************************************************************************
** TestVal
**************************************************************************

@Js
const class TestVal: WrapDict
{
  static new makeNum(Int v, Str s := "")
  {
    makeNumber(Number(v), s)
  }

  static new makeNumber(Number v, Str s := "")
  {
    make(Etc.dict3("val", v, "status", s, "spec", Ref("hx.test.xeto::TestVal")))
  }

  new make(Dict wrap) : super(wrap) {}

  Number val() { get("val") }
  Str status() { get("status") }

  override Int hash() { val.hash.xor(status.hash) }

  override Bool equals(Obj? x)
  {
    that := x as TestVal
    if (that == null) return false
    return this.val == that->val && this.status == that->status
  }

  override Str toStr() { "$val {$status}" }
}

**************************************************************************
** TestFoo
**************************************************************************

@Js
class TestFoo : CompObj
{
  CompChangeEvent? change
  Int numExecutes

  This reset()
  {
    change = null
    return this
  }

  override Void onExecute()
  {
    numExecutes++
  }

  override Void onChange(CompChangeEvent e)
  {
    change = e
  }

  @Api private Obj? onMethodEcho(Obj? x) { x }

  Obj? onMethodBad1(Str x) { null }
  @Api static Obj? onMethodBad2(Str x) { null }
  @Api Obj? onMethodBad3() { null }
  @Api Obj? onMethodBad4(Str a, Str b) { null }
}

**************************************************************************
** TestCounter
**************************************************************************

@Js
class TestCounter : CompObj
{
  override Duration? onExecuteFreq() { 1min }
  override Void onExecute()
  {
    TestVal old := get("out")
    TestVal out := TestVal(old.val + Number.one)
    //echo("~~ execute $this => $old -> $out")
    set("out", out)
  }
}

**************************************************************************
** TestAdd
**************************************************************************

@Js
class TestAdd : CompObj
{

  override Void onExecute()
  {
    TestVal in1 := get("in1")
    TestVal in2 := get("in2")
    out := TestVal(in1.val + in2.val)
    //echo("~~ execute $this => $in1 + $in2 = $out")
    set("out", out)
  }
}

**************************************************************************
** TestNumberAdd
**************************************************************************

@Js
class TestNumberAdd : CompObj
{
  override Void onExecute()
  {
    in1 := get("in1") as Number ?: Number.zero
    in2 := get("in2") as Number ?: Number.zero
    out := in1 + in2
    //echo("~~ execute $this => $in1 + $in2 = $out")
    set("out", out)
  }
}

