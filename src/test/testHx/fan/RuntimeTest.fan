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
    // test that we can add a record
    x := addRec(["dis":"It works!"])
    y := rt.db.readById(x.id)
    verifyEq(y.dis, "It works!")

    // test that required libs are enabled
    verifyEq(rt.lib("ph").name, "ph")
    verifyEq(rt.libs.containsSame(rt.lib("ph")), true)
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
    verifyLibEnabled("hxdApi")
    verifyLibEnabled("hxdUser")
    verifyLibDisabled("hxdHttp")  // not turned on by default
    verifyLibDisabled("hxTestA")
    verifyLibDisabled("hxTestB")

    // cannot add hxTestB because it depends on hxTestA
    verifyErrMsg(DependErr#, "HxLib \"hxTestB\" missing dependency on \"hxTestA\"") { rt.libAdd("hxTestB") }
    verifyLibDisabled("hxTestB")

    // add hxTestA
    a := rt.libAdd("hxTestA") as HxTestALib
    verifyLibEnabled("hxTestA")
    verifySame(rt.lib("hxTestA"), a)
    verifyEq(a.traces.val, "onStart\n")

    // now add hxTestB
    b := rt.libAdd("hxTestB")
    verifyLibEnabled("hxTestB")
    verifySame(rt.lib("hxTestB"), b)

    // cannot remove hxTestA because hxTestB depends on it
    verifyErrMsg(DependErr#, "HxLib \"hxTestB\" has dependency on \"hxTestA\"") { rt.libRemove("hxTestA") }
    rt.libRemove("hxTestB")
    verifyLibDisabled("hxTestB")

    // now remove hxTestB
    rt.libRemove("hxTestA")
    verifyLibDisabled("hxTestA")
    verifyEq(a.traces.val, "onStart\nonStop\n")

  }

  private HxLib verifyLibEnabled(Str name)
  {
    lib := rt.lib(name)
    verifyEq(rt.libs.containsSame(lib), true)
    verifyEq(rt.hasLib(name), true)

    verifyEq(lib.name, name)
    verifySame(lib.rt, rt)
    verifySame(lib.def, rt.ns.lib(name))
    verifyDictEq(lib.rec, rt.db.read("hxLib==$name.toCode"))
    verifyEq(lib.def->def, Symbol("lib:$name"))
    verifySame(rt.ns.lib(name), lib.def)

    return lib
  }

  private Void verifyLibDisabled(Str name)
  {
    verifyEq(rt.lib(name, false), null)
    verifyErr(UnknownLibErr#) { rt.lib(name) }
    verifyErr(UnknownLibErr#) { rt.lib(name, true) }
    verifyEq(rt.libs.find { it.name == name }, null)
    verifyEq(rt.hasLib(name), false)

    verifyEq(rt.db.read("hxLib==$name.toCode", false), null)

    verifyEq(rt.ns.lib(name, false), null)
    verifyErr(UnknownLibErr#) { rt.ns.lib(name) }
    verifyErr(UnknownLibErr#) { rt.ns.lib(name, true) }
  }

//////////////////////////////////////////////////////////////////////////
// Axon
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testAxon()
  {
    cx := makeContext
    verifyEq(cx.ns.def("func:today").lib.name, "axon")
    verifyEq(cx.ns.def("func:userTest").lib.name, "hxdUser")
    verifyEq(cx.eval("today()"), Date.today)
    // TODO
    //verifyEq(cx.eval("userTest()"), "It works?")
  }

}

**************************************************************************
** HxTestLibA
**************************************************************************

const class HxTestALib : HxLib
{
  const AtomicRef traces := AtomicRef("")

  Void trace(Str msg) { traces.val = traces.val.toStr + "$msg\n" }

  override Void onStart() { trace("onStart") }
  override Void onSteadyState() { trace("onSteadyState") }
  override Void onStop() { trace("onStop") }
}

**************************************************************************
** HxTestLibB
**************************************************************************

const class HxTestBLib : HxLib
{
}

