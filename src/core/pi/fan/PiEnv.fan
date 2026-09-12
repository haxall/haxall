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
  virtual Ref normRef(Ref id) { id }

  ** Item wrapper for a spec cached per space namespace
  abstract Item specItem(Spec spec)

  ** Construct an ItemList implementation
  abstract ItemList itemList(Item[] items, Item? self)

  ** Wrap a grid as an ItemGrid collection
  abstract ItemCollection itemGrid(Grid grid)

  ** Display flash notification for an error to the user
  virtual Void flash(Str msg, Err? err := null) { Console.cur.err(msg, err) }
}

