//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Nov 2025  Matthew Giannini  Creation
//

using xeto
using haystack

**
** CompSpaceEdit provides several utilities for editing and manipulating Comps
** in a CompSpace.
**
@Js
class CompSpaceEdit
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(CompSpace cs)
  {
    this.cs = cs
  }

  ** The CompSpace to edit
  CompSpace cs { private set }

//////////////////////////////////////////////////////////////////////////
// Api
//////////////////////////////////////////////////////////////////////////

  // TODO: need more discussion and design around error checking
  // e.g. see ionBlock::BlockLinkCheck - those types of checks moving into xetom

  ** Add a link between two slots
  virtual Void link(Ref fromRef, Str fromSlot, Ref toRef, Str toSlot)
  {
    toComp := cs.readById(toRef)
    toComp.set("links", toComp.links.add(toSlot, Etc.link(fromRef, fromSlot)))
  }

  ** Remove a link between two slots
  virtual Void unlink(Ref fromRef, Str fromSlot, Ref toRef, Str toSlot)
  {
    toComp := cs.readById(toRef)
    toComp.set("links", toComp.links.remove(toSlot, Etc.link(fromRef, fromSlot)))
  }

  ** Create a new Comp whose type is of the given qualified name. Add the new
  ** Comp as a child of the CompSpace root. Returns the newly created Comp.
  **
  **   c := edit.create("sys.comp::Comp")
  virtual Comp create(Str qname)
  {
    spec := cs.ns.spec(qname)
    comp := cs.createSpec(spec)
    cs.root.add(comp)
    return comp
  }

  ** Update the Comp with the given id by setting all its slots with the same name/value
  ** pairs as found in the diff. If the diff contains keys that don't map to slots
  ** on the Comps spec, then those keys are ignored. Returns the updated Comp.
  virtual Comp update(Ref id, Dict diff)
  {
    comp  := cs.readById(id)
    slots := comp.spec.slots
    diff.each |v, n|
    {
      // skip unknown slots
      slotSpec := slots.get(n, false)
      if (slotSpec == null) return

      // attempt to update the slot
      binding := slotSpec.binding
      if (v.typeof.fits(binding.type))
        comp.set(n, v)
      else if (binding.isScalar)
        comp.set(n, binding.decodeScalar(v.toStr))
      else
        throw Err("TODO??? non-scalar ${n} => ${v} (${v.typeof}) binding=${binding}")
    }
    return comp
  }

  ** Remove the Comp with the given id from the CompSpace. If the Comp is not found,
  ** this is a no-op. Throws an Err if you attempt to remove the root Comp.
  **
  ** Note that removing a Comp also causes all links to and from the Comp to be removed.
  virtual Void delete(Ref id)
  {
    comp := cs.readById(id, false)
    if (comp == null) return
    if (comp.parent == null) throw Err("Cannot delete root: ${id}")
    comp.parent.remove(comp.name)
  }
}