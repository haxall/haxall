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
// Edits
//////////////////////////////////////////////////////////////////////////

  // TODO: need more discussion and design around error checking
  // e.g. see ionBlock::BlockLinkCheck - those types of checks moving into xetom

  ** Add a link between two slots
  virtual Void link(Ref fromRef, Str fromSlot, Ref toRef, Str toSlot)
  {
    toComp := readById(toRef)
    toComp.set("links", toComp.links.add(toSlot, Etc.link(fromRef, fromSlot)))
    onCompUpdated(toComp)
  }

  ** Remove a link between two slots
  virtual Void unlink(Ref fromRef, Str fromSlot, Ref toRef, Str toSlot)
  {
    toComp := readById(toRef)
    toComp.set("links", toComp.links.remove(toSlot, Etc.link(fromRef, fromSlot)))
    onCompUpdated(toComp)
  }

  ** Create a new Comp whose type is of the given qualified name. Add the new
  ** Comp as a child of the given parent Comp. You can also configure the default
  ** layout for the Comp by passing in a `CompLayout`.
  ** Returns the newly created Comp.
  **
  **   c := edit.create("sys.comp::Comp")
  **   c := edit.create("sys.comp::Comp", CompLayout(2,2))
  **
  ** See also `layout`
  virtual Comp create(Ref parentId, Str qname, CompLayout? layout := null)
  {
    parent := readById(parentId)
    spec := cs.ns.spec(qname)
    comp := cs.createSpec(spec)
    comp.set("compLayout", layout)
    parent.add(comp)
    onCompAdded(comp)
    return comp
  }

  ** Layout the Comp with the given id. Returns the updated Comp.
  virtual Comp layout(Ref id, CompLayout layout)
  {
    comp := readById(id)
    comp.set("compLayout", layout)
    onCompUpdated(comp)
    return comp
  }

  ** Update the Comp with the given id by setting all its slots with the same name/value
  ** pairs as found in the diff. If the diff contains keys that don't map to slots
  ** on the Comps spec, then those keys are ignored. Returns the updated Comp.
  virtual Comp update(Ref id, Dict diff)
  {
    comp  := readById(id)
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
    onCompUpdated(comp)
    return comp
  }

  ** Convenience to delete all ids
  virtual Void deleteAll(Ref[] ids)
  {
    ids.each |id| { delete(id) }
  }

  ** Remove the Comp with the given id from the CompSpace. If the Comp is not found,
  ** this is a no-op. Throws an Err if you attempt to remove the root Comp.
  **
  ** Note that removing a Comp also causes all links to and from the Comp to be removed.
  virtual Void delete(Ref id)
  {
    comp := readById(id, false)
    if (comp == null) return
    if (comp.parent == null) throw Err("Cannot delete root: ${id}")
    comp.parent.remove(comp.name)
    onCompRemoved(comp)
  }

  ** Duplicate the sub-graph of Comps specified by the given ids and add them
  ** to the CompSpace. Only links between Comps in the sub-graph are duplicated.
  virtual Comp[] duplicate(Ref[] ids)
  {
    // map comps to duplicate by id
    origComps := Ref:Comp[:] { ordered = true }
    Comp? parent := null
    ids.each |id|
    {
      c := readById(id)
      origComps[id] = c

      // sanity check
      if (parent == null) parent = c.parent
      else if (parent !== c.parent) throw Err("Not all comps have the same parent")
    }

    // first just duplicate the comps
    origToDup := Ref:Ref[:]                // original id to duplicated id
    dups := Ref:Comp[:] { ordered = true}  // duplicated comps by id
    origComps.each |comp, id|
    {
      // create the comp and place it shift its location right and down by 1 unit
      layout := comp.get("layout") as CompLayout
      if (layout != null) layout = CompLayout(layout.x+1, layout.y+1, layout.w)
      dup := create(parent.id, comp.spec.qname, layout)

      // update state
      origToDup[id] = dup.id
      dups[dup.id]  = dup
    }

    // now duplicate links within the sub-graph
    origComps.each |comp, id|
    {
      comp.links.eachLink |toSlot, link|
      {
        // if "from" comp is not in the dup graph, ignore this link
        origFrom := origComps[link.fromRef]
        if (origFrom == null) return

        // add the duplicated link
        dupTo   := dups[origToDup[id]]
        dupFrom := dups[origToDup[link.fromRef]]
        this.link(dupFrom.id, link.fromSlot, dupTo.id, toSlot)
      }
    }

    // note we fire added callback by routing to create
    return dups.vals
  }

//////////////////////////////////////////////////////////////////////////
// Overrides
//////////////////////////////////////////////////////////////////////////

  ** Lookup a Comp by id. The default implementation looks up the comp directly in the 'cs'
  ** using `CompSpace.readById`.
  virtual Comp? readById(Ref id, Bool checked := true) {  cs.readById(id, checked) }

  ** Get the root Comp. The default implementation gets the root component from the 'cs'
  ** using `CompSpace.root`
  virtual Comp root() { cs.root }

  ** Callback when component is added
  virtual Void onCompAdded(Comp c) {}

   ** Callback when component is updated
  virtual Void onCompUpdated(Comp c) {}

  ** Callback when component is removed
  virtual Void onCompRemoved(Comp c) {}
}

