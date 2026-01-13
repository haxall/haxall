//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Jun 2025  Matthew Giannini  Creation
//

using concurrent
using haystack
using hx
using xeto
using xetom

abstract class HxCompTest : HxTest
{
  CompSpace? cs

  override Void setup()
  {
    super.setup
    cs = CompSpace(ns).initRoot { Folder() }
    Actor.locals[CompSpace.actorKey] = cs
    cs.start
  }

  override Void teardown()
  {
    cs.stop
    Actor.locals.remove(CompSpace.actorKey)
    super.teardown
  }

  once Namespace ns()
  {
    XetoEnv.cur.createNamespaceFromNames(["hx.comps"])
  }

//////////////////////////////////////////////////////////////////////////
// Comp utils
//////////////////////////////////////////////////////////////////////////

  ** Utility to help with creating new comp instances
  Comp createComp(Obj obj)
  {
    if (obj is Spec) return cs.createSpec(obj)
    if (obj is Str)
    {
      s := obj as Str
      // assume hx.comps lib if not qname
      spec := ns.spec(s.contains("::") ? s : "hx.comps::${s}")
      return createComp(spec)
    }
    if (obj is Dict) return cs.create(obj)
    // create a new instance of this component based on its spec
    if (obj is Comp) return createComp((obj as Comp).spec)
    throw ArgErr("${obj} (${obj.typeof})")
  }

  ** Create the comp using `createComp` and then add it under the root component.
  ** Then immediately call CompSpace.execute and return the new comp
  Comp createAndExec(Obj obj, Str? name := null)
  {
    c := createComp(obj)
    cs.root.add(c, null)
    cs.execute
    return c
  }

  ** Load the comp from its xeto, and add it under the root component.
  ** Then immediately call CompSpace.execute and return the new comp.
  Comp loadComp(Str xeto, Str? name := null)
  {
    c := createComp(ns.io.readXeto(xeto))
    cs.root.add(c, name)
    cs.execute
    return c
  }

  ** Set a comp slot, and then force CompSpace.execute
  Void setAndExec(Comp c, Str name, Obj? val)
  {
    c.set(name, val)
    cs.execute
  }

//////////////////////////////////////////////////////////////////////////
// StatusVal utils
//////////////////////////////////////////////////////////////////////////

  StatusNumber sn(Obj n, Status s := Status.ok)
  {
    num := n as Number
    if (num == null) num = Number((n as Num).toFloat)
    return StatusNumber(num, s)
  }
  StatusBool sb(Bool b, Status s := Status.ok) { StatusBool(b, s) }
  StatusStr ss(Str str, Status s := Status.ok) { StatusStr(str, s) }

//////////////////////////////////////////////////////////////////////////
// Verify utils
//////////////////////////////////////////////////////////////////////////

  Void verifyStatus(StatusVal expected, StatusVal actual)
  {
    verifyEq(expected.typeof, actual.typeof)
    if (expected is StatusNumber)
    {
      e := (StatusNumber)expected
      a := (StatusNumber)actual
      verify(e.num.approx(a.num))
      verifyEq(e.status, a. status)
    }
    else verifyEq(expected, actual)
  }
}

**************************************************************************
** TestCompContext
**************************************************************************

class TestHxCompContext : CompContext
{
  override DateTime now() { DateTime.now }

  Void asCur(|This| f)
  {
    try
    {
      Actor.locals[actorLocalsKey] = this
      f(this)
    }
    finally
    {
      Actor.locals.remove(actorLocalsKey)
    }
  }
}

**************************************************************************
** SimulatedCompContext
**************************************************************************

class SimulatedCompContext : CompContext
{
  new make(CompSpace cs, DateTime start := Date.today.midnight)
  {
    this.cs  = cs
    this.now = start
  }

  private CompSpace cs

  override DateTime now

  ** Set the simulation time to the current timestamp and then
  ** execute the comp space
  This step(DateTime ts)
  {
    this.now = ts
    cs.execute
    return this
  }

  Void asCur(|This| f)
  {
    try
    {
      Actor.locals[actorLocalsKey] = this
      f(this)
    }
    finally
    {
      Actor.locals.remove(actorLocalsKey)
    }
  }
}

