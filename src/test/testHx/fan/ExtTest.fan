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
// Basics
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
    verifyEq(t.traces.val, "onStart[true]\nonReady[true]\nonSteadyState\n")
    verifyEq(t.isRunning, true)

    // now remove hx.txt
    t.traces.val = ""
    proj.libs.remove("hx.test")
    verifyExtDisabled("hx.test")
    t.spi.sync
    verifyEq(t.traces.val, "onUnready[false]\nonStop[false]\n")
    verifyEq(t.isRunning, false)

    // add docker
    addExt("hx.docker")
    addExt("hx.py")
    g := eval("py()")
    echo(">>> $g")
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

    // make update
    ext.settingsUpdate(Diff(ext.settings, ["foo":"bar"]))
    ext.spi.sync
    verifySettings(ext, Etc.dict1("foo", "bar"))
    verifyEq(ext.traces.val, "onSettings[$ext.settings]\n")

    // make another update
    ext.traces.val = ""
    ext.settingsUpdate(Diff(ext.settings, ["foo":Remove.val, "timeout":n(123)]))
    ext.spi.sync
    verifySettings(ext, Etc.dict1("timeout", n(123)))
    verifyEq(ext.traces.val, "onSettings[$ext.settings]\n")

    // now remove, re-add ext with predefined settings
    proj.libs.remove(ext.name)
    ext = addExt("hx.test", ["init":"abc", "beach":m])
    verifySettings(ext, Etc.dict2("init", "abc", "beach", m))
  }

  Void verifySettings(Ext ext, Dict expect)
  {
    actual := ext.settings
    expect = Etc.dictMerge(expect, ["id":Ref("ext.$ext.name"), "mod":actual->mod])
    verifyDictEq(actual, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Services
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testServices()
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

