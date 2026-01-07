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
    createNamespace.io.readXeto(s, opts)
  }

  Dict[] compileDicts(Str s, Dict? opts := null)
  {
    createNamespace.io.readXetoDicts(s, opts)
  }

  Void verifyFlavor(Namespace ns, Spec x, SpecFlavor expect)
  {
    lib    := x.lib
    name   := x.name
    qname  := x.qname
    parent := x.parent

    verifySame(x.flavor,  expect)
    verifyEq(x.isType,    expect.isType)
    verifyEq(x.isMixin,   expect.isMixin)
    verifyEq(x.isMember,  expect.isMember)
    verifyEq(x.isGlobal,  expect.isGlobal)
    verifyEq(x.isSlot,    expect.isSlot)
    verifyEq(parent != null, expect.isMember)

    if (expect.isTop)
    {
      verifySame(lib.spec(name), x)
      verifySame(lib.specs.get(name), x)
      verifySame(lib.specs.list.containsSame(x), true)
    }
    else
    {
      verifySame(parent.member(name), x)
      verifySame(parent.members.get(name), x)
      verifySame(parent.members.list.containsSame(x), true)
    }

    switch (expect)
    {
      case SpecFlavor.type:
        verifySame(lib.type(name), x)
        verifySame(lib.types.get(name), x)
        verifySame(lib.types.list.containsSame(x), true)
        verifySame(lib.mixins.get(name, false), null)
        verifyErr(UnknownSpecErr#) { lib.mixins.get(name) }
        verifyEq(lib.mixins.list.containsSame(x), false)

      case SpecFlavor.mixIn:
        verifySame(lib.mixinFor(x.base), x)
        verifySame(lib.mixins.get(name), x)
        verifySame(lib.mixins.list.containsSame(x), true)
        verifySame(lib.types.get(name, false), null)
        verifyErr(UnknownSpecErr#) { lib.types.get(name) }
        verifyEq(lib.types.list.containsSame(x), false)

      case SpecFlavor.slot:
        verifySame(parent.slot(name), x)
        verifySame(parent.slots.get(name), x)
        verifySame(parent.slots.list.containsSame(x), true)
        // note: slot flavor doesn't mean we haven't inherited global

      case SpecFlavor.global:
        verifySame(parent.globals.get(name), x)
        verifySame(parent.globals.list.containsSame(x), true)
        verifySame(parent.slot(name, false), null)
        verifySame(parent.slots.get(name, false), null)
        verifyErr(UnknownSpecErr#) { parent.slots.get(name) }
        verifyEq(parent.slots.list.containsSame(x), false)

      default:
        fail(x.qname)
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

  static const Str numberPattern := "(-?(?:0|[1-9]\\d*)(?:\\.\\d+)?(?:[eE][+-]?\\d+)?[a-zA-Z%_/\$\\P{ASCII}]*|\"(?:NaN|-?INF)\")"
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

