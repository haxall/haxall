//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Mar 2023  Brian Frank  Creation
//

using concurrent
using util
using xeto
using xeto::Dict
using xeto::Lib
using haystack
using haystack::Ref
using xetoEnv

**
** AbstractXetoTest
**
@Js
class AbstractXetoTest : HaystackTest
{

  Obj none() { Remove.val }

  Obj na() { NA.val }

  Ref ref(Str id, Str? dis := null) { Ref(id, dis) }

  Dict dict0() { Etc.dict0 }

  Dict dict1(Str n0, Obj v0) { Etc.dict1(n0, v0) }

  Dict dict2(Str n0, Obj v0, Str n1, Obj v1) { Etc.dict2(n0, v0, n1, v1) }

  Dict dict(Str:Obj map) { Etc.dictFromMap(map) }

  static Dict nameDictEmpty() { MNameDict.empty }

  Void verifyLocalAndRemote(Str[] libs, |LibNamespace ns| f)
  {
    // first test local server
    server := TestServer(createNamespace(libs))
    verifyEq(server.ns.isRemote, false)
    f(server.ns)

    // setup remote client
    client := TestClient(server)
    client.boot
    verifyEq(client.ns.isRemote, true)
    client.ns.libsAllAsync |e, x|
    {
      try
      {
        if (e != null) throw e
        verifyEq(x.size, server.ns.versions.size)
        f(client.ns)
      }
      catch (Err e2)
      {
        e2.trace
        fail
      }
    }
  }

  LibNamespace sysNamespace()
  {
    LibNamespace.system
  }

  LibNamespace createNamespace(Str[] libs)
  {
    if (libs.size == 1 && libs[0] == "sys")
      return sysNamespace

    repo    := LibRepo.cur
    depends := libs.map |n->LibDepend| { LibDepend(n) }
    vers    := repo.solveDepends(depends)
    return repo.createNamespace(vers)
  }

  Obj? compileData(Str s, Dict? opts := null)
  {
    sysNamespace.compileData(s, opts)
  }

  Dict[] compileDicts(Str s, Dict? opts := null)
  {
    sysNamespace.compileDicts(s, opts)
  }

  Void verifyFlavor(Spec spec, SpecFlavor expect)
  {
    verifySame(spec.flavor, expect)
    verifyEq(spec.isType,   expect.isType)
    verifyEq(spec.isGlobal, expect.isGlobal)
    verifyEq(spec.isMeta,   expect.isMeta)
    verifyEq(spec.isSlot,   expect.isSlot)
    if (expect.isSlot)
      verifyNotNull(spec.parent)
    else
      verifyNull(spec.parent)
  }

  Void verifyFlavorLookup(LibNamespace ns, Spec spec, SpecFlavor flavor)
  {
    lib := spec.lib
    name := spec.name
    qname := spec.qname

    if (flavor.isTop)
    {
      verifyEq(lib.spec(name), spec)
      verifyEq(lib.specs.containsSame(spec), true)
    }

    verifyEq(lib.types.containsSame(spec),     flavor.isType)
//echo("~~ $spec $spec.flavor $lib.globals | $lib.metaSpecs")
//    verifyEq(lib.globals.containsSame(spec),   flavor.isGlobal)
//    verifyEq(lib.metaSpecs.containsSame(spec), flavor.isMeta)

    verifyEq(lib.specs.isImmutable,     true)
    verifyEq(lib.types.isImmutable,     true)
    verifyEq(lib.globals.isImmutable,   true)
    verifyEq(lib.metaSpecs.isImmutable, true)

    switch (flavor)
    {
      case SpecFlavor.type:
        verifySame(lib.type(name), spec)
        verifyEq(lib.global(name, false), null)
        verifyEq(lib.metaSpec(name, false), null)
        verifyErr(UnknownSpecErr#) { lib.global(name) }
        verifyErr(UnknownSpecErr#) { lib.metaSpec(name) }

      case SpecFlavor.global:
        verifySame(lib.global(name), spec)
        verifyEq(lib.type(name, false), null)
        verifyEq(lib.metaSpec(name, false), null)
        verifyErr(UnknownSpecErr#) { lib.type(name) }
        verifyErr(UnknownSpecErr#) { lib.metaSpec(name) }

      case SpecFlavor.meta:
        verifySame(lib.metaSpec(name), spec)
        verifyEq(lib.type(name, false), null)
//        verifyEq(lib.global(name, false), null)
        verifyErr(UnknownSpecErr#) { lib.type(name) }
//        verifyErr(UnknownSpecErr#) { lib.global(name) }

      case SpecFlavor.slot:
        verifyNotNull(spec.parent, null)

      default:
        fail
    }

  }

  Void verifyFitsExplain(LibNamespace ns, Obj? val, Spec spec, Str[] expected)
  {
    cx := TestContext()
    hits := XetoLogRec[,]
    explain := |XetoLogRec rec| { hits.add(rec) }
    opts := Etc.dict1("explain", Unsafe(explain))
    ns.fits(cx, val, spec, opts)
    if (expected.size != hits.size)
    {
      echo("FAIL verifyFitsExplain $val $spec [$hits.size != $expected.size]")
      echo(hits.join("\n"))
      fail
    }
    expected.each |expect, i|
    {
      verifyEq(expect, hits[i].msg)
    }
  }

  Void verifyCompEq(Comp c, Str:Obj expect)
  {
    names := expect.dup
    c.each |v, n|
    {
      try
      {
        verifyValEq(v, expect[n])
      }
      catch (TestErr e)
      {
        echo("TAG FAILED: $n")
        throw e
      }
      names.remove(n)
    }
    verifyEq(names.size, 0, names.keys.toStr)
  }

  static Str normTempLibName(Str str)
  {
    prefix := "\"temp"
    s := str.index(prefix) ?: str.index(prefix = "'temp")
    if (s == null) return str

    e := s+5
    while (str[e].isDigit) e++

    name := str[s..<e]
    return str.replace(name, prefix)
  }

}

**************************************************************************
** TestContext
**************************************************************************

@Js
class TestContext : XetoContext
{
  override Dict? xetoReadById(Obj id) { recs.get(id) }
  override Obj? xetoReadAllEachWhile(Str filter, |Dict->Obj?| f) { null }
  override Bool xetoIsSpec(Str spec, Dict rec) { false }
  Ref:Dict recs := [:]
}

**************************************************************************
** TestServer
**************************************************************************

@Js
const class TestServer
{
  new make(LibNamespace ns)
  {
    this.ns = ns
    this.io = XetoBinaryIO.makeServer(ns)
  }

  const LibNamespace ns
  const XetoBinaryIO io
}

**************************************************************************
** TestClient
**************************************************************************

@Js
const class TestClient : RemoteLibLoader
{
  new make(TestServer server) { this.server = server }

  const TestServer server

  RemoteNamespace? ns() { nsRef.val }
  const AtomicRef nsRef := AtomicRef()

  XetoBinaryIO io() { ns.io }

  const Bool debug := false

  This boot()
  {
    buf := Buf()
    server.io.writer(buf.out).writeBoot(server.ns)
    if (debug) echo("   ~~~ init remote bootstrap size = $buf.size bytes ~~~")

    ns := RemoteNamespace.boot(buf.flip.in, null, this)
    nsRef.val = ns
    return this
  }

  override Void loadLib(Str name, |Err?, Obj?| f)
  {
    serverLib := server.ns.lib(name, false)
    if (serverLib == null) { f(UnknownLibErr(name), null); return }

    buf := Buf()
    server.io.writer(buf.out).writeLib(serverLib)
    if (debug) echo("   ~~~ load lib $name size = $buf.size bytes ~~~")

    clientLib := io.reader(buf.flip.in).readLib(ns)
    f(null, clientLib)
  }
}

**************************************************************************
** XetoFactoryLoader
**************************************************************************

@Js
internal const class TestBindingLoader : SpecBindingLoader
{
  override Void load(SpecBindings acc, Str libName, CSpec[] specs)
  {
    acc.add(TestValBinding("$libName::TestVal", TestVal#))

    /*
    //acc["IFoo"]        = InterfaceSpecFactory(IFoo#)
    acc["TestAdd"]     = CompSpecFactory(TestAdd#)
    acc["TestCounter"] = CompSpecFactory(TestCounter#)
    acc["TestFoo"]     = CompSpecFactory(TestFoo#)
    */
  }
}

**************************************************************************
** XetoFactoryLoader
**************************************************************************

@Js
internal const class XetoFactoryLoader: SpecFactoryLoader
{
  override Str:SpecFactory load(Str libName, Str[] specNames)
  {
    if (libName != "hx.test.xeto") throw Err(libName)
    pod := typeof.pod
    acc := Str:SpecFactory[:]
    //acc["IFoo"]        = InterfaceSpecFactory(IFoo#)
    acc["TestAdd"]     = CompSpecFactory(TestAdd#)
    acc["TestCounter"] = CompSpecFactory(TestCounter#)
    acc["TestFoo"]     = CompSpecFactory(TestFoo#)
    acc["TestVal"]     = TestValSpecFactory(TestVal#)
    return acc
  }
}

@Js
internal const class TestValBinding : DictBinding
{
  new make(Str spec, Type type) : super(spec, type) {}
  override Dict decodeDict(Dict xeto) { TestVal(xeto) }
}


@Js
internal const class TestValSpecFactory : DictSpecFactory
{
  new make(Type type) : super(type) {}
  override Dict decodeDict(Dict xeto, Bool checked := true) { TestVal(xeto) }
}

