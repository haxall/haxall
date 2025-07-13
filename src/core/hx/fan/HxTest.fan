//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 May 2021  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio

**
** HxTest is a base class for writing Haxall tests which provide
** access to a booted runtime instance.  Annotate test methods which
** require a runtime with `HxTestProj`.  This class uses the 'hxd'
** implementation for its runtime.
**
**   @HxTestProj
**   Void testBasics()
**   {
**     x := addRec(["dis":"It works!"])
**     y := rt.db.readById(x.id)
**     verifyEq(y.dis, "It works!")
**   }
**
abstract class HxTest : HaystackTest
{

//////////////////////////////////////////////////////////////////////////
// Test Setup
//////////////////////////////////////////////////////////////////////////

  ** If '@HxTestProj' configured then open `rt`
  override Void setup()
  {
    if (curTestMethod.hasFacet(HxTestProj#)) projStart
  }

  ** If '@HxTestProj' configured then close down `rt`
  override Void teardown()
  {
    Actor.locals.remove(ActorContext.actorLocalsKey)
    if (projRef != null) projStop
    tempDir.delete
  }

//////////////////////////////////////////////////////////////////////////
// Runtime (@HxTestProj)
//////////////////////////////////////////////////////////////////////////

  ** TODO
  @Deprecated Proj? rt(Bool checked := true) { proj(checked) }

  ** Get system if '@HxTestProj' configured on test method
  Sys? sys(Bool checked := true)
  {
    proj(checked)?.sys
  }

  ** Test project if '@HxTestProj' configured on test method
  Proj? proj(Bool checked := true)
  {
    if (projRef != null || !checked) return projRef
    throw Err("Runtime not started (ensure $curTestMethod marked @HxTestProj)")
  }

  ** Reference for `proj`
  @NoDoc Proj? projRef

  ** Start a test runtime which is accessible via `rt` method.
  @NoDoc virtual Void projStart()
  {
    if (projRef != null) throw Err("Runtime already started!")
    projMeta := Etc.emptyDict
    facet := curTestMethod.facet(HxTestProj#, false) as HxTestProj
    if (facet != null && facet.meta != null)
    {
      if (facet.meta is Str)
        projMeta = TrioReader(facet.meta.toStr.in).readDict
      else
        projMeta = Etc.makeDict((Str:Obj)facet.meta)
    }
    projRef = spi.start(projMeta)
  }

  ** Stop test runtime
  @NoDoc virtual Void projStop()
  {
    if (projRef == null) throw Err("Runtime not started!")
    spi.stop(projRef)
    projRef = null
  }

  ** Stop, then restart test runtime
  @NoDoc virtual Void projRestart()
  {
    projStop
    projStart
  }

  ** Service provider interface
  @NoDoc virtual HxTestSpi spi() { spiDef }

  ** Create service provider interface
  private once HxTestSpi spiDef()
  {
    // check if running in a SkySpark environment,
    // otherwise fallback to use hxd implemenntation
    type := Type.find("skyarcd::ProjHxTestSpi", false) ?: Type.find("hxd::HxdTestSpi")
    return type.make([this])
  }

//////////////////////////////////////////////////////////////////////////
// Folio Conveniences
//////////////////////////////////////////////////////////////////////////

  ** Convenience for 'read' on `rt`
  Dict? read(Str filter, Bool checked := true)
  {
    proj.db.read(Filter(filter), checked)
  }

  ** Convenience for 'readById' on `rt`
  Dict? readById(Ref id, Bool checked := true)
  {
    proj.db.readById(id, checked)
  }

  ** Convenience for commit to `rt`
  Dict? commit(Dict rec, Obj? changes, Int flags := 0)
  {
    proj.db.commit(Diff.make(rec, changes, flags)).newRec
  }

  ** Add a record to `rt` using the given map of tags.
  Dict addRec(Str:Obj? tags := Str:Obj?[:])
  {
    // strip out null
    tags = tags.findAll |v, n| { v != null }

    id := tags["id"] as Ref
    if (id != null)
    {
      if (id.isProjRec) id = id.toProjRel
      tags.remove("id")
    }
    else
    {
      id = Ref.gen
    }
    return proj.db.commit(Diff.makeAdd(tags, id)).newRec
  }

  ** Add a library and all its depdenencies to the runtime.
  Ext addLib(Str libName, Str:Obj? tags := Str:Obj?[:])
  {
    lib := spi.addLib(libName, tags)
    proj.sync
    lib.spi.sync
    return lib
  }

  ** Add user record to the user database.  If the user
  ** already exists, it is removed
  @NoDoc User addUser(Str user, Str pass, Str:Obj? tags := Str:Obj?[:])
  {
    spi.addUser(user, pass, tags)
  }

  ** Generate a ref to for the runtime database with proper prefix
  @NoDoc Ref genRef(Str id := Ref.gen.id)
  {
    if (proj.db.idPrefix != null) id = proj.db.idPrefix + id
    return Ref(id)
  }

  ** Force transition to steady state
  @NoDoc Void forceSteadyState()
  {
    spi.forceSteadyState(proj)
  }

//////////////////////////////////////////////////////////////////////////
// Axon
//////////////////////////////////////////////////////////////////////////

  ** Create a new context with the given user.  If user is null,
  ** then use a default test user with superuser permissions.
  virtual Context makeContext(User? user := null)
  {
    spi.makeContext(user)
  }

  ** Evaluate an Axon expression using a super user context.
  Obj? eval(Str axon)
  {
    makeContext(null).eval(axon)
  }
}

**************************************************************************
** HxTestProj
**************************************************************************

**
** Annotates a `HxTest` method to setup a test project
**
facet class HxTestProj
{
  ** Database meta data encoded as a Trio string
  const Obj? meta
}

**************************************************************************
** HxTestSpi
**************************************************************************

**
** HxTest service provider interface
**
@NoDoc
abstract class HxTestSpi
{
  new make(HxTest test) { this.test = test }
  HxTest test { private set }
  abstract Proj start(Dict projMeta)
  abstract Void stop(Proj rt)
  abstract User addUser(Str user, Str pass, Str:Obj? tags)
  abstract Ext addLib(Str libName, Str:Obj? tags)
  abstract Context makeContext(User? user)
  abstract Void forceSteadyState(Proj rt)
}

