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
const class PiEnv
{
  ** Current environment: the PiEnv of the current actor context such
  ** as a server runtime, else the global one registered for the VM
  static This? cur(Bool checked := true)
  {
    cx := ActorContext.cur(false) as PiContext
    if (cx != null) return cx.pi
    v := curRef.val
    if (v != null) return v
    if (checked) throw Err("PiEnv not avail")
    return null
  }

  ** Get the PiEnv cached in the given ref, or create one when the
  ** namespace has changed since it was cached
  @NoDoc static PiEnv cached(AtomicRef ref, Namespace ns)
  {
    env := ref.val as PiEnv
    if (env == null || env.ns !== ns) ref.val = env = make(ns)
    return env
  }

  static const AtomicRef curRef := AtomicRef()

  ** Construct for the given namespace
  @NoDoc new make(Namespace ns)
  {
    this.ns  = ns
    this.spi = Type.find("pim::MPiEnvSpi").make([this])
  }

  ** Current namespace
  const Namespace ns

  ** Service provider interface
  @NoDoc const PiEnvSpi spi

  ** Relativize id in the current runtime
  virtual Ref normRef(Ref id) { id }

  ** Display flash notification for an error to the user
  virtual Void flash(ItemStatus status, Str msg, Err? err := null) { Console.cur.err(msg, err) }

  ** Read the given record ids from the runtime.  The future
  ** completes with a grid of one row per id in the order requested
  ** where an unresolvable id is an empty row.  Environments without
  ** a runtime connection complete with an empty grid.
  virtual PiFuture readByIds(Ref[] ids) { PiFuture().complete(Etc.makeEmptyGrid) }

  ** Item wrapper for a spec cached per space namespace
  Item specItem(Spec spec) { spi.specItem(spec) }

  ** Merged presentation info for a spec
  Pi pi(Spec spec) { spi.pi(spec) }

  ** Compile a sketch template with its formal params against this
  ** namespace.  Not cached: each Pi compiles its own sketches once
  @NoDoc Sketch sketch(Str src, Str[] params) { spi.sketch(src, params) }

  ** Construct an ItemList implementation
  ItemList itemList(Item[] items, Item? self) { spi.itemList(items, self) }

  ** Wrap a grid as an ItemGrid collection
  ItemCollection itemGrid(Grid grid) { spi.itemGrid(grid) }

  ** Map a value to an enumeration.  Handles every shape the `enum`
  ** tag is allowed to take: comma or newline separated keys, a
  ** markdown "- key: doc" list, a dict of dicts, a list of keys, and
  ** a Ref to a Xeto `sys::Enum` spec.  Returns `EnumItems.none` if
  ** the value does not map to an enumeration.
  EnumItems enum(Obj? val) { spi.enum(val) }

  ** Map a Xeto `sys::Enum` spec to its enumeration.  Returns
  ** `EnumItems.none` if the spec is not an enum.
  EnumItems enumForSpec(Spec spec) { spi.enumForSpec(spec) }

  ** Cache of the records read by id from the runtime
  PiRecCache recCache() { spi.recCache }

  ** Connector model registry
  once PiConns conns() { PiConns(ns) }
}

**************************************************************************
** PiEnvSpi
**************************************************************************

**
** PiEnvSpi is the service provider interface
**
@NoDoc @Js
abstract const class PiEnvSpi
{
  abstract Item specItem(Spec spec)
  abstract Pi pi(Spec spec)
  abstract Sketch sketch(Str src, Str[] params)
  abstract ItemList itemList(Item[] items, Item? self)
  abstract ItemCollection itemGrid(Grid grid)
  abstract EnumItems enum(Obj? val)
  abstract EnumItems enumForSpec(Spec spec)
  abstract PiRecCache recCache()
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

