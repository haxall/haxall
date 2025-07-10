//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jul 2023  Brian Frank  Creation
//

using xeto
using xetom
using haystack

**
** FactoryTest
**
@Js
class FactoryTest : AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Bindings
//////////////////////////////////////////////////////////////////////////

  Void testBindings()
  {
    // echo(SpecBindings.cur.list.sort.join("\n"))
    verifyScalarBinding("sys::Bool", Bool#, true)
    verifyScalarBinding("sys::Int", Int#, 123)
    verifyScalarBinding("sys::Float", Float#, 123f)
    verifyScalarBinding("sys::Number", Number#, n(123, "kW"))
    verifyScalarBinding("sys::Unit", Unit#, Unit("kW"))
    verifyScalarBinding("sys::Marker", Marker#, Marker.val)
  }

  Void verifyScalarBinding(Str spec, Type type, Obj v)
  {
    reg := SpecBindings.cur
    b := reg.forSpec(spec) ?: throw Err()
    verifySame(reg.forType(type), b)
    verifySame(b.type, type)
    verifyEq(b.spec, spec)
    verifyValEq(b.decodeScalar(v.toStr), v)
    verifyValEq(b.decodeScalar("bad bad", false), null)
  }

//////////////////////////////////////////////////////////////////////////
// Sys
//////////////////////////////////////////////////////////////////////////

  Void testSys()
  {
    verifyLocalAndRemote(["sys"]) |ns| { doTestSys(ns) }
  }

  private Void doTestSys(LibNamespace ns)
  {
    verifyScalar(ns, "sys::Str",     "hello")
    verifyScalar(ns, "sys::Bool",     true)
    verifyScalar(ns, "sys::Int",      123)
    verifyScalar(ns, "sys::Float",    123f)
    verifyScalar(ns, "sys::Duration", 10sec)
    verifyScalar(ns, "sys::Date",     Date("2023-07-01"))
    verifyScalar(ns, "sys::Time",     Time("13:00:00"))
    verifyScalar(ns, "sys::DateTime", DateTime.now)
    verifyScalar(ns, "sys::Uri",      `foo.txt`)
    verifyScalar(ns, "sys::Version",  Version("1.2.3"))

    verifyScalar(ns, "sys::Marker",   Marker.val)
    verifyScalar(ns, "sys::None",     Remove.val)
    verifyScalar(ns, "sys::NA",       NA.val)
    verifyScalar(ns, "sys::Number",   Number(80, Unit("%")))
    verifyScalar(ns, "sys::Ref",      Ref("abc"))
    verifyScalar(ns, "sys::Unit",     Unit("%"))
    verifyScalar(ns, "sys::Span",     Span.today)
    verifyScalar(ns, "sys::SpanMode", SpanMode.lastYear)
    verifyScalar(ns, "sys::Version",  Version("3.5"))
    verifyScalar(ns, "sys::Buf",      Buf().print("xyz"), Buf#)
    verifyScalar(ns, "sys::Filter",   Filter("a and b"), Filter#)
    verifyScalar(ns, "sys::LibDependVersions", LibDependVersions("6.x.x"), LibDependVersions#)

    verifySame(ns.spec("sys::Obj").fantomType, Obj#)
    verifySame(ns.spec("sys::Dict").fantomType, Dict#)
    verifySame(ns.spec("sys::Spec").fantomType, Spec#)
    verifySame(ns.spec("sys::LibOrg").fantomType, Dict#)
    verifySame(ns.spec("sys::LibDepend").fantomType, LibDepend#)
  }

  Void testSysComp()
  {
    ns := createNamespace(["sys", "sys.comp"])

    // Link
    Link link := ns.compileData(Str<|sys.comp::Link { fromRef:"a", fromSlot:"b"}|>)
    verifyEq(link.fromRef,  Ref("a"))
    verifyEq(link.fromSlot, "b")
    verifyEq(ns.specOf(link), ns.spec("sys.comp::Link"))

    // Links - single
    Links links := ns.compileData(
      Str<|sys.comp::Links {
             c: sys.comp::Link { fromRef:"a", fromSlot:"b" }
           }|>)
    verifyDictsEq((Dict[])(Obj)links.listOn("c"), [link])
    verifyEq(ns.specOf(links), ns.spec("sys.comp::Links"))

    // Links - list
    links = ns.compileData(
      Str<|sys.comp::Links {
             c: List {
               sys.comp::Link { fromRef:"a", fromSlot:"b" }
               sys.comp::Link { fromRef:"x", fromSlot:"b" }
             }
           }|>)
    link2 := Etc.link(Ref("x"), "b")
    verifyDictsEq((Dict[])(Obj)links.listOn("c"), [link, link2])
    verifyEq(ns.specOf(links), ns.spec("sys.comp::Links"))
  }

  Void testPh()
  {
    ns := createNamespace(["sys", "ph"])

    verifyScalar(ns, "ph::Coord",     Coord(23f, 45f))
    verifyScalar(ns, "ph::Symbol",    Symbol("tag"), Symbol#)

    // what to do with this guy?
    //verifyScalar("ph::XStr", XStr("Foo", "bar"))
  }

  Void testHxTest()
  {
    ns := createNamespace(["hx.test.xeto"])

    spec := ns.spec("hx.test.xeto::ScalarA")
    binding := (GenericScalarBinding)spec.binding
    verifyEq(binding.type, Scalar#)
    verifyEq(binding.isScalar, true)
    verifyEq(binding.spec, "hx.test.xeto::ScalarA")

    dict := ns.instance("hx.test.xeto::scalars")
    // dict.each |v, n|{ echo("$n = $v [$v.typeof]") }

    Scalar a := dict["a"]
    verifyEq(a.qname, "hx.test.xeto::ScalarA")
    verifyEq(a.val, "alpha")
    verifyEq(a, Scalar("hx.test.xeto::ScalarA", "alpha"))
    verifyNotEq(a, Scalar("bad", "alpha"))
    verifyNotEq(a, Scalar("hx.test.xeto::ScalarA", "bad"))

    Scalar b := dict["b"]
    verifyEq(b.qname, "hx.test.xeto::ScalarB")
    verifyEq(b.val, "beta")
    verifyEq(b, Scalar("hx.test.xeto::ScalarB", "beta"))
    verifyNotEq(b, Scalar("bad", "beta"))
    verifyNotEq(b, Scalar("hx.test.xeto::ScalarB", "bad"))
  }

  Void verifyScalar(LibNamespace ns, Str qname, Obj val, Type? type := val.typeof)
  {
    spec := ns.spec(qname)
    // echo("\n---> $spec | $spec.binding | $spec.fantomType")
    verifySame(spec.binding.type, type)
    s := spec.binding.encodeScalar(val)
    v := spec.binding.decodeScalar(s)
    // echo("::: $type <=> $spec | $v")
    verifyValEq(v, val)
    verifySame(ns.specOf(v), spec)
    verifySame(ns.specOf(v.typeof), spec)
    verifySame(spec.fantomType, type)
  }

}

