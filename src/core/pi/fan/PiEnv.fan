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
  ** Current environment: the PiEnv of the current actor context such
  ** as a server runtime, else the global one registered for the VM
  static PiEnv? cur(Bool checked := true)
  {
    cx := ActorContext.curx(false) as PiContext
    if (cx != null) return cx.pi
    v := curRef.val
    if (v != null) return v
    if (checked) throw Err("PiEnv not avail")
    return null
  }

  ** Construct the pim implementation for the given namespace
  @NoDoc static PiEnv create(Namespace ns)
  {
    Type.find("pim::MPiEnv").make([ns])
  }

  ** Get the PiEnv cached in the given ref, or create one when the
  ** namespace has changed since it was cached
  @NoDoc static PiEnv cached(AtomicRef ref, Namespace ns)
  {
    env := ref.val as PiEnv
    if (env == null || env.ns !== ns) ref.val = env = create(ns)
    return env
  }

  static const AtomicRef curRef := AtomicRef()

  ** Current namespace
  abstract Namespace ns()

  ** Relativize id in the current runtime
  abstract Ref normRef(Ref id)

  ** Item wrapper for a spec cached per space namespace
  abstract Item specItem(Spec spec)

  ** Merged presentation info for a spec
  abstract Pi pi(Spec spec)

  ** Compile a sketch template against this namespace; cached by src
  @NoDoc abstract Sketch sketch(Str src)

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
  abstract PiFuture readByIds(Ref[] ids)

  ** Read the given record ids from the runtime.  The future
  ** completes with a grid of one row per id in the order requested
  ** where an unresolvable id is an empty row.  Environments without
  ** a runtime connection complete with an empty grid.
  abstract PiRecCache recCache()

  ** Connector model registry
  once PiConns conns() { PiConns(ns) }
}

**************************************************************************
** PiContext
**************************************************************************

**
** PiContext is implemented by an actor context which provides the
** PiEnv for its namespace such as a server side runtime context.
**
@NoDoc @Js
mixin PiContext : ActorContext
{
  ** PiEnv for this context's namespace
  abstract PiEnv pi()
}

