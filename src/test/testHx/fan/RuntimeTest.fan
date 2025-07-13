//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using axon
using obs
using folio
using hx

**
** RuntimeTest
**
class RuntimeTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testBasics()
  {
    // name
    verifyEq(rt.dir, rt.dir.normalize)
    verifyEq(rt.dir.name, rt.name)

    // test that we can add a record
    x := addRec(["dis":"It works!"])
    y := rt.db.readById(x.id)
    verifyEq(y.dis, "It works!")

    // test that required exts are enabled
    ext := rt.exts.get("hx.crypto")
    verifyEq(ext.name, "hx.crypto")
    verifyEq(ext.spec.qname, "hx.crypto::CryptoExt")
    verifySame(ext.spec, rt.ns.spec("hx.crypto::CryptoExt"))
    verifyEq(rt.exts.list.containsSame(ext), true)

    // test some method
    http := rt.sys.http
    verifyEq(http.siteUri.isAbs, true)
    verifyEq(http.siteUri.scheme == "http" || rt.sys.http.siteUri.scheme == "https", true)
    verifyEq(http.apiUri.isAbs, false)
    verifyEq(http.apiUri.isDir, true)

    // verify legacy defs
    verifyEq(rt.defs.def("lib:ph")->def, Symbol("lib:ph"))
    verifyEq(rt.defs.def("lib:crypto")->def, Symbol("lib:crypto"))
  }

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  @HxTestProj { meta =
    Str<|dis: "My Test"
         steadyState: 100ms
         fooBar|> }
  Void testMeta()
  {
    // verify test setup with meta data correctly
    rec := rt.db.read(Filter("projMeta"))
    meta := rt.meta
    verifySame(rt.meta, meta)
    verifyEq(meta.id, rec.id)
    verifyEq(meta->dis, "My Test")
    verifyEq(meta->steadyState, n(100, "ms"))
    verifyEq(meta->fooBar, m)

    // verify changes to meta
    rec = commit(rec, ["dis":"New Dis", "newTag":"!"])
    verifyNotSame(rt.meta, meta)
    meta = rt.meta
    verifyEq(meta->dis, "New Dis")
    verifyEq(meta->newTag, "!")

    // verify cannot remove/trash/add
    verifyErr(DiffErr#) { addRec(["dis":"Another one", "projMeta":m]) }
    verifyErr(DiffErr#) { commit(rec, ["projMeta":Remove.val]) }
    verifyErr(CommitErr#) { commit(rec, null, Diff.remove) }
    verifyErr(CommitErr#) { commit(rec, ["trash":m]) }

    // verify steady state timer
    verifyEq(rt.isSteadyState, false)
    Actor.sleep(150ms)
    verifyEq(rt.isSteadyState, true)
  }

//////////////////////////////////////////////////////////////////////////
// LibMgr
//////////////////////////////////////////////////////////////////////////

/* TODO
  @HxTestProj
  Void testLibMgr()
  {
    verifyLibEnabled("ph")
    verifyLibEnabled("phIoT")
    verifyLibEnabled("hx")
    verifyLibEnabled("crypto")
    verifyLibDisabled("hxTestA")
    verifyLibDisabled("hxTestB")

    // verify core lib
    core := rt.libsOld.get("hx")
    verifySame(rt.defs.def("func:read").lib, core.def)

    // cannot add hxTestB because it depends on hxTestA
    errLibName := rt.typeof.pod.name == "hxd" ? "Ext" : "Ext"
    verifyErrMsg(DependErr#, "$errLibName \"hxTestB\" missing dependency on \"hxTestA\"") { rt.libsOld.add("hxTestB") }
    verifyLibDisabled("hxTestB")

    // verify can't add/update/remove lib directly
    verifyErr(DiffErr#) { rt.db.commit(Diff.makeAdd(["ext":"hxTestA"])) }
    verifyErr(DiffErr#) { rt.db.commit(Diff.make(core.rec, ["ext":"renameMe"])) }
    verifyErr(CommitErr#) { rt.db.commit(Diff.make(core.rec, null, Diff.remove)) }

    // add hxTestA
    forceSteadyState
    verifyEq(rt.isSteadyState, true)
    a := rt.libsOld.add("hxTestA") as HxTestAExt
    verifyLibEnabled("hxTestA")
    verifySame(rt.libsOld.get("hxTestA"), a)
    verifyEq(a.traces.val, "onStart[true]\nonReady[true]\nonSteadyState\n")
    verifyEq(a.isRunning, true)

    // now add hxTestB
    b := rt.libsOld.add("hxTestB")
    verifyLibEnabled("hxTestB")
    verifySame(rt.libsOld.get("hxTestB"), b)

    // cannot remove hxTestA because hxTestB depends on it
    verifyErrMsg(DependErr#, "$errLibName \"hxTestB\" has dependency on \"hxTestA\"") { rt.libsOld.remove("hxTestA") }
    rt.libsOld.remove("hxTestB")
    verifyLibDisabled("hxTestB")

    // now remove hxTestB
    a.traces.val = ""
    rt.libsOld.remove("hxTestA")
    verifyLibDisabled("hxTestA")
    verifyEq(a.traces.val, "onUnready[false]\nonStop[false]\n")
    verifyEq(a.isRunning, false)
  }

  private Ext verifyLibEnabled(Str name)
  {
    lib := rt.libsOld.get(name)
    verifySame(rt.libsOld.get(name), lib)
    verifyEq(rt.libsOld.list.containsSame(lib), true)
    verifyEq(rt.libsOld.has(name), true)

    verifyEq(lib.name, name)
    verifySame(lib.def, rt.defs.lib(name))
    verifyEq(lib.def->def, Symbol("lib:$name"))
    verifySame(rt.defs.lib(name), lib.def)

    // only in hxd environments
    rec := read("ext==$name.toCode", false)
    if (rec != null) verifyDictEq(lib.rec, rec)

    return lib
  }

  private Void verifyLibDisabled(Str name)
  {
    verifyEq(rt.libsOld.get(name, false), null)
    verifyEq(rt.libsOld.get(name, false), null)
    verifyErr(UnknownLibErr#) { rt.libsOld.get(name) }
    verifyErr(UnknownLibErr#) { rt.libsOld.get(name, true) }
    verifyEq(rt.libsOld.list.find { it.name == name }, null)
    verifyEq(rt.libsOld.has(name), false)

    verifyEq(read("ext==$name.toCode", false), null)

    verifyEq(rt.defs.lib(name, false), null)
    verifyErr(UnknownLibErr#) { rt.defs.lib(name) }
    verifyErr(UnknownLibErr#) { rt.defs.lib(name, true) }
  }
*/
//////////////////////////////////////////////////////////////////////////
// Services
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testServices()
  {
    // makeSyntheticUser
    u := rt.sys.user.makeSyntheticUser("FooBar", ["bar":"baz"])
    if (rt.platform.isSkySpark)
      verifyEq(u.id, Ref("u:FooBar"))
    else
      verifyEq(u.id, Ref("FooBar"))
    verifyEq(u.username, "FooBar")
    verifyEq(u.meta["bar"], "baz")
    verifyErr(ParseErr#) { rt.sys.user.makeSyntheticUser("Foo Bar", ["bar":"baz"]) }
  }

//////////////////////////////////////////////////////////////////////////
// Axon
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testAxon()
  {
    // verify via Axon eval
    cx := makeContext
    verifyEq(cx.defs.def("func:today").lib.name, "axon")
    verifyEq(cx.defs.def("func:commit").lib.name, "hx")
    verifyEq(cx.eval("today()"), Date.today)

    // sysmod functions
    verifyEq(cx.eval("cryptoReadAllKeys().col(\"alias\").name"), "alias")

    // add library
    cx.eval("libAdd(\"hx.math\")")
    verifyEq(cx.defs.def("func:sqrt").lib.name, "math")
    verifyEq(cx.eval("sqrt(16)"), n(4))

    // verify funcs thru Fantom APIs
    Actor.locals[ActorContext.actorLocalsKey] = cx
    rec := addRec(["dis":"Test"])
    verifySame(HxCoreFuncs.readById(rec.id), rec)
    HxCoreFuncs.commit(Diff(rec, ["foo":m]))
    verifyEq(HxCoreFuncs.readById(rec.id)->foo, m)
  }
}

**************************************************************************
** HxTestLibA
**************************************************************************

const class HxTestAExt : ExtObj
{
  const AtomicRef traces := AtomicRef("")

  Void trace(Str msg) { traces.val = traces.val.toStr + "$msg\n" }

  override const Observable[] observables := [TestObservable()]

  override Void onStart() { trace("onStart[$isRunning]") }
  override Void onReady() { trace("onReady[$isRunning]") }
  override Void onSteadyState() { trace("onSteadyState") }
  override Void onUnready() { trace("onUnready[$isRunning]") }
  override Void onStop() { trace("onStop[$isRunning]") }
}

**************************************************************************
** HxTestLibB
**************************************************************************

const class HxTestBExt : ExtObj
{
}

