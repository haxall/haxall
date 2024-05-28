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
using haystack::Dict
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
    this.factory = CompFactory(this)
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
  virtual Comp root() { rootRef ?: throw Err("Must call initRoot") }

//////////////////////////////////////////////////////////////////////////
// Hooks
//////////////////////////////////////////////////////////////////////////

  ** Callback anytime a component in the space is modified.
  ** The name and value are the slot modified, or null for a remove.
  virtual Void onChange(Comp comp, Str name, Obj? val) {}

//////////////////////////////////////////////////////////////////////////
// Comp Management
//////////////////////////////////////////////////////////////////////////

  ** Initialize server provider interface for given instance
  override CompSpi initSpi(CompObj c, Spec? spec)
  {
    factory.initSpi(c, spec)
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

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private CompFactory factory
  private Comp? rootRef
  private Ref:Comp byId := [:]
}

