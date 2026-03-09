//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//    9 Mar 2026  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack

**
** MCompFunc is base class for CompFunc implementations
**
@Js
abstract const class MCompFunc : CompFunc
{
  ** Constructor with name
  new make(Str name) { this.name = name }

  ** Slot name
  const Str name

  ** Map to func type for given comp
  internal abstract Spec funcType(Comp self)

  ** Subclass hook to implement call
  internal abstract Obj? doCall(Comp self, Obj? arg)

  ** Debug string
  override Str toStr() { "CompFunc $name" }
}

**************************************************************************
** SpecCompFunc
**************************************************************************

**
** Static comp func backed by func spec
**
@Js
internal const class SpecCompFunc : MCompFunc
{
  new make(Spec slot) : super(slot.name) {}

  override Spec funcType(Comp self)
  {
    self.spec.slot(name)
  }

  override Obj? doCall(Comp self, Obj? arg)
  {
    funcType(self).func.thunk.callComp(self, arg)
  }
}

**************************************************************************
** DictCompFunc
**************************************************************************

**
** Instance comp func backed by instance dict
**
@Js
internal const class DictCompFunc : MCompFunc
{
  new make(Str name, Dict val) : super(name)
  {
    this.name = name
    this.meta = val
  }

  const Dict meta

  override Spec funcType(Comp self)
  {
    ns := self.spi.ns
    ref := meta["funcType"] as Ref
    if (ref == null) return ns.lib("sys.comp").spec("CompFuncDefaultType")
    return ns.spec(ref.id)
  }

  override Obj? doCall(Comp self, Obj? arg)
  {
    throw Err("TODO")
  }
}

