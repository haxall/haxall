//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//

using concurrent
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

  @HxRuntimeTest
  Void testBasics()
  {
    // name
    verifyEq(rt.dir, rt.dir.normalize)
    verifyEq(rt.dir.name, rt.name)

    // test that we can add a record
    x := addRec(["dis":"It works!"])
    y := rt.db.readById(x.id)
    verifyEq(y.dis, "It works!")

    // test that required libs are enabled
    verifyEq(rt.lib("ph").name, "ph")
    verifyEq(rt.libs.list.containsSame(rt.lib("ph")), true)

    // test some methods
    verifyEq(rt.http.siteUri.isAbs, true)
    verifyEq(rt.http.siteUri.scheme == "http" || rt.http.siteUri.scheme == "https", true)
    verifyEq(rt.http.apiUri.isAbs, false)
    verifyEq(rt.http.apiUri.isDir, true)
  }

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest { meta =
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

  @HxRuntimeTest
  Void testLibMgr()
  {
    verifyLibEnabled("ph")
    verifyLibEnabled("phIoT")
    verifyLibEnabled("hx")
    verifyLibEnabled("crypto")
    verifyLibDisabled("hxTestA")
    verifyLibDisabled("hxTestB")

    // verify core lib
    core := rt.lib("hx")
    verifySame(rt.ns.def("func:read").lib, core.def)

    // cannot add hxTestB because it depends on hxTestA
    errLibName := rt.typeof.pod.name == "hxd" ? "HxLib" : "Ext"
    verifyErrMsg(DependErr#, "$errLibName \"hxTestB\" missing dependency on \"hxTestA\"") { rt.libs.add("hxTestB") }
    verifyLibDisabled("hxTestB")

    // verify can't add/update/remove lib directly
    verifyErr(DiffErr#) { rt.db.commit(Diff.makeAdd(["ext":"hxTestA"])) }
    verifyErr(DiffErr#) { rt.db.commit(Diff.make(core.rec, ["ext":"renameMe"])) }
    verifyErr(CommitErr#) { rt.db.commit(Diff.make(core.rec, null, Diff.remove)) }

    // add hxTestA
    forceSteadyState
    verifyEq(rt.isSteadyState, true)
    a := rt.libs.add("hxTestA") as HxTestALib
    verifyLibEnabled("hxTestA")
    verifySame(rt.lib("hxTestA"), a)
    verifyEq(a.traces.val, "onStart[true]\nonReady[true]\nonSteadyState\n")
    verifyEq(a.isRunning, true)

    // now add hxTestB
    b := rt.libs.add("hxTestB")
    verifyLibEnabled("hxTestB")
    verifySame(rt.lib("hxTestB"), b)

    // cannot remove hxTestA because hxTestB depends on it
    verifyErrMsg(DependErr#, "$errLibName \"hxTestB\" has dependency on \"hxTestA\"") { rt.libs.remove("hxTestA") }
    rt.libs.remove("hxTestB")
    verifyLibDisabled("hxTestB")

    // now remove hxTestB
    a.traces.val = ""
    rt.libs.remove("hxTestA")
    verifyLibDisabled("hxTestA")
    verifyEq(a.traces.val, "onUnready[false]\nonStop[false]\n")
    verifyEq(a.isRunning, false)
  }

  private HxLib verifyLibEnabled(Str name)
  {
    lib := rt.lib(name)
    verifySame(rt.libs.get(name), lib)
    verifyEq(rt.libs.list.containsSame(lib), true)
    verifyEq(rt.libs.has(name), true)

    verifyEq(lib.name, name)
    verifySame(lib.def, rt.ns.lib(name))
    verifyEq(lib.def->def, Symbol("lib:$name"))
    verifySame(rt.ns.lib(name), lib.def)

    // only in hxd environments
    rec := read("ext==$name.toCode", false)
    if (rec != null) verifyDictEq(lib.rec, rec)

    return lib
  }

  private Void verifyLibDisabled(Str name)
  {
    verifyEq(rt.lib(name, false), null)
    verifyEq(rt.libs.get(name, false), null)
    verifyErr(UnknownLibErr#) { rt.lib(name) }
    verifyErr(UnknownLibErr#) { rt.lib(name, true) }
    verifyEq(rt.libs.list.find { it.name == name }, null)
    verifyEq(rt.libs.has(name), false)

    verifyEq(read("ext==$name.toCode", false), null)

    verifyEq(rt.ns.lib(name, false), null)
    verifyErr(UnknownLibErr#) { rt.ns.lib(name) }
    verifyErr(UnknownLibErr#) { rt.ns.lib(name, true) }
  }

//////////////////////////////////////////////////////////////////////////
// Services
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testServices()
  {
    // makeSyntheticUser
    u := rt.user.makeSyntheticUser("FooBar", ["bar":"baz"])
    if (rt.platform.isSkySpark)
      verifyEq(u.id, Ref("u:FooBar"))
    else
      verifyEq(u.id, Ref("FooBar"))
    verifyEq(u.username, "FooBar")
    verifyEq(u.meta["bar"], "baz")
    verifyErr(ParseErr#) { rt.user.makeSyntheticUser("Foo Bar", ["bar":"baz"]) }
  }

//////////////////////////////////////////////////////////////////////////
// Axon
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testAxon()
  {
    // verify via Axon eval
    cx := makeContext
    verifyEq(cx.ns.def("func:today").lib.name, "axon")
    verifyEq(cx.ns.def("func:libAdd").lib.name, "hx")
    verifyEq(cx.eval("today()"), Date.today)

    // sysmod functions
    verifyEq(cx.eval("cryptoReadAllKeys().col(\"alias\").name"), "alias")

    // add library
    cx.eval("libAdd(\"math\")")
    verifyEq(cx.ns.def("func:sqrt").lib.name, "math")
    verifyEq(cx.eval("sqrt(16)"), n(4))

    // verify funcs thru Fantom APIs
    Actor.locals[Etc.cxActorLocalsKey] = cx
    rec := addRec(["dis":"Test"])
    verifySame(HxCoreFuncs.readById(rec.id), rec)
    HxCoreFuncs.commit(Diff(rec, ["foo":m]))
    verifyEq(HxCoreFuncs.readById(rec.id)->foo, m)
  }
}

**************************************************************************
** HxTestLibA
**************************************************************************

const class HxTestALib : HxLib
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

const class HxTestBLib : HxLib
{
}

