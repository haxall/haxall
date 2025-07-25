//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//   21 Jul 2025  Brian Frank  Refactor for 4.0
//

using concurrent
using xeto
using haystack
using axon
using obs
using folio
using hx
using hxm

**
** ExtTest
**
class ExtTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Add/Remove
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testAddRemove()
  {
    verifyExtDisabled("hx.test")

    // verify required sys ext
    crypto := verifyExtEnabled("hx.crypto")

    // add hx.test
    forceSteadyState
    verifyEq(proj.isSteadyState, true)
    proj.libs.add("hx.test")
    HxTestExt t := verifyExtEnabled("hx.test")
    t.spi.sync
    verifyEq(t.traces.val, "onStart[true]\nonReady[true]\nonSteadyState\n")
    verifyEq(t.isRunning, true)

    // now remove hx.txt
    t.traces.val = ""
    proj.libs.remove("hx.test")
    verifyExtDisabled("hx.test")
    t.spi.sync
    verifyEq(t.traces.val, "onUnready[false]\nonStop[false]\n")
    verifyEq(t.isRunning, false)
  }

  private Ext verifyExtEnabled(Str name)
  {
    // ProjExts
    ext := proj.exts.get(name)
    verifySame(proj.ext(name), ext)
    verifySame(proj.exts.get(name), ext)
    verifyEq(proj.exts.list.containsSame(ext), true)
    verifyEq(proj.exts.has(name), true)

    // ProjLibs
    verifyEq(proj.libs.get(name).name, ext.name)

    // Namespace
    verifyEq(proj.ns.lib(name).name, ext.name)
    verifySame(proj.ns.lib(name), ext.spec.lib)
    verifySame(proj.ns.lib(name).type(ext.typeof.name), ext.spec)

    return ext
  }

  private Void verifyExtDisabled(Str name)
  {
    // ProjExts
    verifyEq(proj.exts.get(name, false), null)
    verifyEq(proj.exts.get(name, false), null)
    verifyErr(UnknownExtErr#) { proj.exts.get(name) }
    verifyErr(UnknownExtErr#) { proj.exts.get(name, true) }
    verifyEq(proj.exts.list.find { it.name == name }, null)
    verifyEq(proj.exts.has(name), false)

    // ProjLibs
    verifyEq(proj.libs.get(name, false), null)
    verifyErr(UnknownLibErr#) { proj.libs.get(name) }
    verifyErr(UnknownLibErr#) { proj.libs.get(name, true) }

    // Namespace
    verifyEq(proj.ns.lib(name, false), null)
    verifyErr(UnknownLibErr#) { proj.ns.lib(name) }
    verifyErr(UnknownLibErr#) { proj.ns.lib(name, true) }
  }

//////////////////////////////////////////////////////////////////////////
// GetByType
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testGetByType()
  {
    // not found stuff
    verifyGetByTypeNotFound(Str#)

    // verify system services
    sys := proj.sys
    verifySame(verifyGetByType(ICryptoExt#), sys.crypto)
    verifySame(verifyGetByType(IProjExt#),   sys.proj)
    verifySame(verifyGetByType(IUserExt#),   sys.user)

    // add hx.io
    verifyGetByTypeNotFound(IIOExt#)
    proj.libs.add("hx.io")
    verifySame(verifyGetByType(IIOExt#), proj.exts.io)

    // remove hx.io
    proj.libs.remove("hx.io")
    verifyGetByTypeNotFound(IIOExt#)
  }

  Ext verifyGetByType(Type t)
  {
    ext := proj.exts.getByType(t)
    verifyEq(proj.exts.getAllByType(t).containsSame(ext), true)
    verifyEq(proj.exts.list.containsSame(ext), true)
    verifySame(proj.exts.getAllByType(t), proj.exts.getAllByType(t))
    return ext
  }

  Void verifyGetByTypeNotFound(Type t)
  {
    verifyEq(proj.exts.getByType(t, false), null)
    verifyEq(proj.exts.getAllByType(t), Ext[,])
    verifyNotSame(proj.exts.getAllByType(t), proj.exts.getAllByType(t)) // don't cache misses
    verifyErr(UnknownExtErr#) { proj.exts.getByType(t) }
    verifyErr(UnknownExtErr#) { proj.exts.getByType(t, true) }
  }

//////////////////////////////////////////////////////////////////////////
// Settings
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testSettings()
  {
    HxTestExt ext := addExt("hx.test")
    verifySettings(ext, Etc.dict0)

    // make some invalid updates
    ext.traces.val = ""
    verifyErr(UnknownNameErr#) { ext.settingsUpdate(Diff(Etc.dict0, null)) }
    verifyErr(DiffErr#) { ext.settingsUpdate(Diff.makeAdd(["foo":m])) }
    verifyErr(DiffErr#) { ext.settingsUpdate(Diff(ext.settings, null, Diff.remove)) }
    verifyErr(DiffErr#) { ext.settingsUpdate(Diff(ext.settings, ["id":Remove.val])) }
    verifyErr(DiffErr#) { ext.settingsUpdate(Diff(ext.settings, ["mod":Remove.val])) }
    verifyEq(ext.traces.val, "")

    // make update - Diff
    ext.settingsUpdate(Diff(ext.settings, ["foo":"bar"]))
    verifySettings(ext, Etc.dict1("foo", "bar"))
    verifyEq(ext.traces.val, "onSettings[$ext.settings]\n")

    // make update - Dict
    ext.traces.val = ""
    ext.settingsUpdate(Etc.dict2("foo", "bar2", "port", n(123)))
    verifySettings(ext, Etc.dict2("foo", "bar2", "port", n(123)))
    verifyEq(ext.traces.val, "onSettings[$ext.settings]\n")

    // make update - Str:Obj
    ext.traces.val = ""
    ext.settingsUpdate(["foo":"bar3", "port":Remove.val])
    verifySettings(ext, Etc.dict1("foo", "bar3"))
    verifyEq(ext.traces.val, "onSettings[$ext.settings]\n")

    // make another update
    ext.traces.val = ""
    ext.settingsUpdate(Diff(ext.settings, ["foo":Remove.val, "timeout":n(123), "qux":m]))
    ext.spi.sync
    verifySettings(ext, Etc.dict2("timeout", n(123), "qux", m))
    verifyEq(ext.traces.val, "onSettings[$ext.settings]\n")

    // restart project and verify persisted
    oldProj := this.proj
    projRestart
    verifyNotSame(proj, oldProj)
    ext = proj.exts.get("hx.test")
    verifySettings(ext, Etc.dict2("timeout", n(123), "qux", m))

    // now remove, re-add ext with predefined settings (clears existing ones)
    proj.libs.remove(ext.name)
    ext = addExt("hx.test", ["init":"abc", "beach":m])
    verifySettings(ext, Etc.dict2("init", "abc", "beach", m))

    // restart project and verify persisted
    projRestart
    ext = proj.exts.get("hx.test")
    verifySettings(ext, Etc.dict2("init", "abc", "beach", m))
  }

  Void verifySettings(Ext ext, Dict expect)
  {
    ext.spi.sync
    actual := ext.settings
    // echo("--> verify $ext $actual")
    expect = Etc.dictMerge(expect, ["id":Ref("ext.$ext.name"), "mod":actual->mod])
    verifyDictEq(actual, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Axon
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testAxon()
  {
    // axon lib
    cx := makeContext
    verifyEq(cx.eval("today()"), Date.today)

    // hx.foo libs
    verifyEq(cx.eval("cryptoReadAllKeys().col(\"alias\").name"), "alias")

    // add library
    cx.eval("libAdd(\"hx.math\")")
    verifyEq(cx.defs.def("func:sqrt").lib.name, "math")
    verifyEq(cx.eval("sqrt(16)"), n(4))

    // verify funcs thru Fantom APIs
    Actor.locals[ActorContext.actorLocalsKey] = cx
    rec := addRec(["dis":"Test"])
    verifySame(HxFuncs.readById(rec.id), rec)
    HxFuncs.commit(Diff(rec, ["foo":m]))
    verifyEq(HxFuncs.readById(rec.id)->foo, m)
  }

//////////////////////////////////////////////////////////////////////////
// IUserExt
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testUserExt()
  {
    // makeSyntheticUser
    u := proj.sys.user.makeSyntheticUser("FooBar", ["bar":"baz"])
    if (sys.info.rt.isSkySpark)
      verifyEq(u.id, Ref("u:FooBar"))
    else
      verifyEq(u.id, Ref("FooBar"))
    verifyEq(u.username, "FooBar")
    verifyEq(u.meta["bar"], "baz")
    verifyErr(ParseErr#) { proj.sys.user.makeSyntheticUser("Foo Bar", ["bar":"baz"]) }
  }

//////////////////////////////////////////////////////////////////////////
// IFileExt
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testFileExt()
  {
    proj.dir.plus(`io/`).create

    // "io/"
    f := verifyFileResolve(`io/`, true)
    verifyEq(f.isDir, true)
    verifyEq(f.list, File[,])
    if (sys.info.rt.isSkySpark)
      verifyEq(f.parent.uri, `/proj/${proj.name}/`)
    else
      verifyEq(f.parent, null)

    // "io/a.txt"
    f = verifyFileResolve(`io/a.txt`, false)
    verifyEq(f.exists, false)
    f.create
    verifyEq(f.exists, true)
    verifyEq(f.size, 0)
    verifyEq(f.parent.uri, normUri(`io/`))
    verifyEq(f.readAllStr, "")
    f.out.print("hi").close
    verifyEq(f.size, 2)
    verifyEq(f.readAllStr, "hi")
    verifyFileResolve(`io/a.txt`, true)

    // "io/sub"
    f = verifyFileResolve(`io/sub/`, false)
    f.create
    verifyEq(f.exists, true)
    verifyEq(f.size, null)
    verifyEq(f.isDir, true)

    // "io/" listing
    f = verifyFileResolve(`io/`, true)
    list := f.list.dup.sort |a, b| { a.name <=> b.name }
    verifyEq(list.size, 2)
    verifyEq(list[0].uri, normUri(`io/a.txt`))
    verifyEq(list[1].uri, normUri(`io/sub/`))

    // various bad URIs
    verifyFileUnsupported(`bad.txt`)
    verifyFileUnsupported(`io/../bad.txt`)
  }

  File verifyFileResolve(Uri uri, Bool exists)
  {
    f := proj.exts.file.resolve(uri)
    verifyEq(f.uri, normUri(uri))
    verifyEq(f.isDir, uri.isDir)
    verifyEq(f.exists, exists)
    return f
  }

  Uri normUri(Uri uri)
  {
    if (uri.toStr.startsWith("io/"))
    {
      return sys.info.rt.isSkySpark ? "/proj/${proj.name}/${uri}".toUri : uri
    }
    return uri
  }

  Void verifyFileUnsupported(Uri uri)
  {
    try
    {
      f := proj.exts.file.resolve(uri)
      verify(!f.exists)
    }
    catch (UnsupportedErr e)
    {
      verify(true)
    }
  }
}

**************************************************************************
** HxTestExt
**************************************************************************

const class HxTestExt : ExtObj
{
  const AtomicRef traces := AtomicRef("")

  Void trace(Str msg) { traces.val = traces.val.toStr + "$msg\n" }

  override const Observable[] observables := [TestObservable()]

  override Void onStart() { trace("onStart[$isRunning]") }
  override Void onReady() { trace("onReady[$isRunning]") }
  override Void onSteadyState() { trace("onSteadyState") }
  override Void onUnready() { trace("onUnready[$isRunning]") }
  override Void onStop() { trace("onStop[$isRunning]") }
  override Void onSettings() { trace("onSettings[$settings]") }
}

