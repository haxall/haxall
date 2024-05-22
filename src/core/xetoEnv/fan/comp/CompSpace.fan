//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 May 2024  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using haystack::Ref

**
** CompSpace manages a tree of components.  It is the base class for
** different component applications for control, Ion UI, and remote
** programming
**
@Js
class CompSpace : CompSpiFactory
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make(LibNamespace ns)
  {
    this.ns = ns
  }

  ** Initialize the root - this must be called exactly once during initialization
  This initRoot(|This->Comp| f)
  {
    if (rootRef != null) throw Err("Root already initialized")

    // use callback to make root while this is installed as actor local
    Actor.locals[actorKey] = this
    try
      this.rootRef = f(this)
    finally
    Actor.locals.remove(actorKey)
    mount(root)

    return this
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Xeto namespace for this space
  const LibNamespace ns

  ** Root component
  Comp root() { rootRef ?: throw Err("Must call initRoot") }

//////////////////////////////////////////////////////////////////////////
// Comp Management
//////////////////////////////////////////////////////////////////////////

  ** Create service provider for given component
  override CompSpi initSpi(CompObj c, Spec? spec)
  {
    // infer spec from type if not passed in
    if (spec == null) spec = ns.specOf(c)

    // TODO create default values
    slots := Str:Obj[:]
    slots["id"] = genId
    slots["spec"] = spec._id

    // return component spec
    return MCompSpi(this, c, spec, slots)
  }

  ** Read by id
  Comp? readById(Ref id, Bool checked := true)
  {
    c := byId.get(id)
    if (c != null) return c
    if (checked) throw UnknownRecErr(id.toStr)
    return null
  }

  ** Recursively mount component into this space
  internal Void mount(Comp c)
  {
    // add to my lookup tables
    byId.add(c.id, c)

    // recurse children
    c.eachChild |kid| { mount(kid) }
  }

  ** Recursively unmount component into this space
  internal Void unmount(Comp c)
  {
    // recurse children
    c.eachChild |kid| { unmount(kid) }

    // remove from my lookup tables
    byId.remove(c.id)
  }

  ** Generate id for new component
  internal haystack::Ref genId()
  {
    compCounter++
    return haystack::Ref(""+compCounter)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private Comp? rootRef
  private Int compCounter
  private Ref:Comp byId := [:]
}

