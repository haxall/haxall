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
using xetom
using haystack

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

  Void verifyLocalAndRemote(Str[] libs, |Namespace ns| f)
  {
    // first test local server
    server := TestServer(createNamespace(libs))
    verifyEq(server.ns.env.isRemote, false)
    f(server.ns)

    // setup remote client
    client := TestClient(server)
    client.boot
    verifyEq(client.ns.env.isRemote, true)

    // check lib lookup
    cns := client.ns
    libs.each |n|
    {
      if (n == "sys") return
      verifyEq(cns.hasLib(n), true)
      verifyEq(cns.libStatus(n), LibStatus.ok)
      verifyEq(cns.lib(n).name, n)
      if (n == "ph") verifyEq(client.ns.spec("ph::Site").name, "Site")
    }

    // load all and invoke callback
    verifyEq(client.ns.libs.size, server.ns.versions.size)
    f(client.ns)
  }

  Namespace createNamespace(Str[] libs := ["sys"])
  {
    XetoEnv.cur.createNamespaceFromNames(libs)
  }

  Obj? compileData(Str s, Dict? opts := null)
  {
    createNamespace.compileData(s, opts)
  }

  Dict[] compileDicts(Str s, Dict? opts := null)
  {
    createNamespace.compileDicts(s, opts)
  }

  Void verifyFlavor(Spec spec, SpecFlavor expect)
  {
    verifySame(spec.flavor, expect)
    verifyEq(spec.isType,   expect.isType)
    verifyEq(spec.isGlobal, expect.isGlobal)
    verifyEq(spec.isSlot,   expect.isSlot)
    if (expect.isSlot)
      verifyNotNull(spec.parent)
    else
      verifyNull(spec.parent)
  }

  Void verifyFlavorLookup(Namespace ns, Spec spec, SpecFlavor flavor)
  {
    lib := spec.lib
    name := spec.name
    qname := spec.qname

    if (flavor.isTop)
    {
      verifyEq(lib.spec(name), spec)
      verifyEq(lib.specs.containsSame(spec), true)
    }

    verifyEq(lib.specs.isImmutable,     true)
    verifyEq(lib.types.isImmutable,     true)
    verifyEq(lib.mixins.isImmutable,    true)

    verifyEq(lib.types.contains(spec),     flavor === SpecFlavor.type)
    verifyEq(lib.mixins.contains(spec),    flavor === SpecFlavor.mixIn)

    switch (flavor)
    {
      case SpecFlavor.type:
        verifySame(lib.type(name), spec)
        verifyEq(lib.mixins.find { it.name == name}, null)

      case SpecFlavor.mixIn:
        verifySame(lib.mixins.find { it.name == name}, spec)
        verifyEq(lib.type(name, false), null)
        verifyErr(UnknownSpecErr#) { lib.type(name) }

      case SpecFlavor.slot:
        verifyNotNull(spec.parent, null)

      default:
        fail
    }

  }

  Void verifyFitsExplain(Namespace ns, Obj? val, Spec spec, Str[] expected)
  {
    hits := XetoLogRec[,]
    explain := |XetoLogRec rec| { hits.add(rec) }
    opts := Etc.dict1("explain", Unsafe(explain))
    ns.fits(val, spec, opts)
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
    s := str.index(prefix)
    if (s == null)
    {
      prefix = "'temp"
      s = str.index(prefix)
    }
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
  Void asCur(|This| f)
  {
    Actor.locals[actorLocalsKey] = this
    f(this)
    Actor.locals.remove(actorLocalsKey)
  }

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
  new make(Namespace ns)
  {
    this.ns = ns
  }

  const Namespace ns
}

**************************************************************************
** TestClient
**************************************************************************

@Js
const class TestClient //: RemoteLibLoader
{
  new make(TestServer server) { this.server = server }

  const TestServer server

  const MEnv remoteEnv := RemoteEnv()

  Namespace? ns() { nsRef.val }
  const AtomicRef nsRef := AtomicRef()

  const Bool debug := false

  This boot()
  {
    buf := Buf()
    XetoBinaryWriter(buf.out).writeLibs(server.ns.libs)
    if (debug) echo("   ~~~ init remote bootstrap size = $buf.size bytes ~~~")

    remoteEnv := RemoteEnv()
    vers := remoteEnv.loadLibs(buf.flip.in)
    ns := remoteEnv.createNamespace(vers)
    nsRef.val = ns
    return this
  }

  /*
  override Void loadLib(Str name, |Err?, Obj?| f)
  {
    serverLib := server.ns.lib(name, false)
    if (serverLib == null) { f(UnknownLibErr(name), null); return }

    buf := Buf()
    XetoBinaryWriter(buf.out).writeLibs([serverLib])
    if (debug) echo("   ~~~ load lib $name size = $buf.size bytes ~~~")

    remoteEnv.loadLibs(buf.flip.in)
    f(null, remoteEnv.get(name))
  }
  */
}

**************************************************************************
** XetoFactoryLoader
**************************************************************************

@Js
internal const class TestBindingLoader : SpecBindingLoader
{
  override Void loadLib(SpecBindings acc, Str libName)
  {
    acc.add(TestValBinding ("$libName::TestVal",     TestVal#))
    acc.add(CompBinding    ("$libName::TestAdd",     TestAdd#))
    acc.add(CompBinding    ("$libName::TestCounter", TestCounter#))
    acc.add(CompBinding    ("$libName::TestFoo",     TestFoo#))
    acc.add(CompBinding    ("$libName::TestNumberAdd", TestNumberAdd#))
  }

  override Thunk loadThunk(Spec spec)
  {
    ThunkFactory.cur.create(spec, typeof.pod)
  }
}

@Js
internal const class TestValBinding : DictBinding
{
  new make(Str spec, Type type) : super(spec, type) {}
  override Dict decodeDict(Dict xeto) { TestVal(xeto) }
}

