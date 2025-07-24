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
using axon
using folio

**
** HxTest is a base class for writing Haxall tests which provide
** access to a booted project instance.  Annotate test methods which
** require a project with `HxTestProj`.  This class uses the 'hxd'
** implementation for its project.
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


  ** Setup actor local for context
  @NoDoc Void setupContext(Context? cx := null)
  {
    Actor.locals[Context.actorLocalsKey] = cx ?: makeContext
  }

//////////////////////////////////////////////////////////////////////////
// Proj (@HxTestProj)
//////////////////////////////////////////////////////////////////////////

  ** Get system if '@HxTestProj' configured on test method
  Sys? sys(Bool checked := true)
  {
    proj(checked)?.sys
  }

  ** Test project if '@HxTestProj' configured on test method
  Proj? proj(Bool checked := true)
  {
    if (projRef != null || !checked) return projRef
    throw Err("Proj not started (ensure $curTestMethod marked @HxTestProj)")
  }

  ** Reference for `proj`
  @NoDoc Proj? projRef

  ** Start a test project which is accessible via `proj` method.
  @NoDoc virtual Void projStart()
  {
    if (projRef != null) throw Err("Proj already started!")
    projMeta := Etc.dict0
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

  ** Stop test project
  @NoDoc virtual Void projStop()
  {
    if (projRef == null) throw Err("Proj not started!")
    spi.stop(projRef)
    projRef = null
  }

  ** Stop, then restart test project
  @NoDoc virtual Void projRestart()
  {
    if (projRef == null) throw Err("Proj not started!")
    projRef = spi.restart(projRef)
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

  ** Convenience for 'read' on `proj`
  Dict? read(Str filter, Bool checked := true)
  {
    proj.read(filter, checked)
  }

  ** Convenience for 'readById' on `proj`
  Dict? readById(Ref id, Bool checked := true)
  {
    proj.db.readById(id, checked)
  }

  ** Convenience for commit to `proj`
  Dict? commit(Dict rec, Obj? changes, Int flags := 0)
  {
    proj.commit(Diff.make(rec, changes, flags)).newRec
  }

  ** Add a record to `proj` using the given map of tags.
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
    return proj.commit(Diff.makeAdd(tags, id)).newRec
  }

  ** Add a library and all its depdenencies to the project.
  Void addLib(Str libName)
  {
    spi.addLib(libName)
  }

  ** Convenience to add extension lib with optional setting and return it
  Ext addExt(Str libName, Str:Obj? tags := Str:Obj?[:])
  {
    spi.addExt(libName, tags)
  }

  ** Convenience for 'proj.specs.addFunc'
  Spec addFunc(Str name, Str src, Obj? meta := null)
  {
    proj.specs.addFunc(name, src, Etc.makeDict(meta))
  }

  ** Add user record to the user database.  If the user
  ** already exists, it is removed
  @NoDoc User addUser(Str user, Str pass, Str:Obj? tags := Str:Obj?[:])
  {
    spi.addUser(user, pass, tags)
  }

  ** Generate a ref to for the project database with proper prefix
  @NoDoc Ref genRef(Str id := Ref.gen.id)
  {
    if (proj.db.idPrefix != null) id = proj.db.idPrefix + id
    return Ref(id)
  }

  ** Force transition to steady state
  @NoDoc Void forceSteadyState()
  {
    spi.forceSteadyState
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

  ** Evaluate axon expression to a Grid
  @NoDoc Grid evalToGrid(Str axon) { eval(axon) }

  ** Verfiy evaluation raises given error type (wrapped by EvalErr)
  @NoDoc Void verifyEvalErr(Str axon, Type? errType)
  {
    expr := Parser(Loc.eval, axon.in).parse
    cx := makeContext
    EvalErr? err := null
    try { expr.eval(cx) } catch (EvalErr e) { err = e }
    if (err == null) fail("EvalErr not thrown: $axon")
    if (errType == null)
    {
      verifyNull(err.cause)
    }
    else
    {
      if (err.cause == null) fail("EvalErr.cause is null: $axon")
      ((Test)this).verifyErr(errType) { throw err.cause }
    }
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
  abstract Void stop(Proj proj)
  abstract Proj restart(Proj proj)
  abstract User addUser(Str user, Str pass, Str:Obj? tags)
  abstract Void addLib(Str libName)
  abstract Ext addExt(Str libName, Str:Obj? tags)
  abstract Context makeContext(User? user)
  abstract Void forceSteadyState()
}

