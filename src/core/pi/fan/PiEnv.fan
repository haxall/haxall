//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Seps 2026  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack

**
** PiEnv
**
@NoDoc @Js
abstract const class PiEnv
{
  ** Current environment for VM
  static PiEnv? cur() { curRef.val ?: throw Err("PiEnv not avail") }

  static const AtomicRef curRef := AtomicRef()

  ** Current namespace
  abstract Namespace ns()

  ** Relativize id in the current runtime
  abstract Ref normRef(Ref id)

  ** Item wrapper for a spec cached per space namespace
  abstract Item specItem(Spec spec)

  ** Construct an ItemList implementation
  abstract ItemList itemList(Item[] items, Item? self)

  ** Wrap a grid as an ItemGrid collection
  abstract ItemCollection itemGrid(Grid grid)

  ** Map a value to an enumeration.  Handles every shape the `enum`
  ** tag is allowed to take: comma or newline separated keys, a
  ** markdown "- key: doc" list, a dict of dicts, a list of keys, and
  ** a Ref to a Xeto `sys::Enum` spec.  Returns `EnumItems.none` if
  ** the value does not map to an enumeration.
  abstract EnumItems enum(Obj? val)

  ** Map a Xeto `sys::Enum` spec to its enumeration.  Returns
  ** `EnumItems.none` if the spec is not an enum.
  abstract EnumItems enumForSpec(Spec spec)

  ** Display flash notification for an error to the user
  abstract Void flash(ItemStatus status, Str msg, Err? err := null)

  ** Read the given record ids from the runtime.  The future
  ** completes with a grid of one row per id in the order requested
  ** where an unresolvable id is an empty row.  Environments without
  ** a runtime connection complete with an empty grid.
  virtual PiFuture readByIds(Ref[] ids) { PiFuture().complete(Etc.makeEmptyGrid) }

  ** Connector model registry
  once PiConns conns() { PiConns(ns) }
}

