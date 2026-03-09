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
@NoDoc @Js
abstract const class MCompFunc : WrapDict, CompFunc
{
  new make(Dict wrap) : super(wrap) {}

  ** Map to func type for given comp
  abstract Spec funcType(Comp self)

  ** Subclass hook to implement call
  abstract Obj? doCall(Comp self, Obj? arg)

  ** Debug string
  override Str toStr() { "CompFunc" }
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
  new make(Spec slot) : super(slot.metaOwn) { this.name = slot.name }

  const Str name

  override Spec funcType(Comp self)
  {
    self.spec.slot(name)
  }

  override Obj? doCall(Comp self, Obj? arg)
  {
    funcType(self).func.thunk.callComp(self, arg)
  }
}

