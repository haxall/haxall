//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jul 2023  Brian Frank  Creation
//

using xeto
using xeto::Dict
using haystack
using haystack::Ref

**
** FactoryTest
**
@Js
class FactoryTest : AbstractXetoTest
{

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
    verifyScalar(ns, "sys::Span",     Span.today)

    verifySame(ns.spec("sys::Obj").fantomType, Obj#)
    verifySame(ns.spec("sys::Dict").fantomType, Dict#)
    verifySame(ns.spec("sys::Spec").fantomType, Spec#)
    verifySame(ns.spec("sys::LibOrg").fantomType, Dict#)
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
    verifyDictsEq((haystack::Dict[])(Obj)links.listOn("c"), [link])
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
    verifyDictsEq((haystack::Dict[])(Obj)links.listOn("c"), [link, link2])
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

  Void verifyScalar(LibNamespace ns, Str qname, Obj val, Type? type := val.typeof)
  {
    spec := ns.spec(qname)
    verifySame(spec.factory.type, type)
    // echo("---> $spec | $spec.factory | $spec.fantomType")
    s := spec.factory.encodeScalar(val)
    v := spec.factory.decodeScalar(s)
    // echo("::: $type <=> $spec | $v")
    verifyEq(v, val)
    verifySame(ns.specOf(v), spec)
    verifySame(ns.specOf(v.typeof), spec)
    verifySame(spec.fantomType, type)
  }

}

