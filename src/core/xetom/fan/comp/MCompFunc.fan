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
  ** Bind specs when CompSpace namespace is updated
  abstract Void updateNamespace(Namespace ns)

  ** Choke-point for all component function calls
  override final Obj? call(Comp self, Obj? arg)
  {
    ret := doCall(self, arg)
    return ret
  }

  ** Subclass hook to implement call
  abstract Obj? doCall(Comp self, Obj? arg)

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
const class SpecCompFunc : MCompFunc
{
  new make(Spec funcType) { this.funcType = funcType }

  override Void updateNamespace(Namespace ns)
  {
    #funcType->setConst(this, ns.spec(funcType.qname))
  }

  override const Spec funcType

  override Str name() { funcType.name }

  override Dict meta() { funcType.meta }

  override Obj? doCall(Comp self, Obj? arg) { funcType.func.thunk.callComp(self, arg) }
}

**************************************************************************
** DictCompFunc
**************************************************************************

**
** Instance comp func backed by instance dict
**
@Js
const class DictCompFunc : MCompFunc
{
  new make(MNamespace ns, Str name, Dict val)
  {
    this.name     = name
    this.meta     = val
    this.funcType = toFuncType(ns)
  }

  override Void updateNamespace(Namespace ns)
  {
    #funcType->setConst(this, toFuncType(ns))
  }

  private Spec toFuncType(MNamespace ns)
  {
    ref := meta["funcType"] as Ref
    if (ref == null) return ns.lib("sys.comp").spec("CompFuncDefaultType")
    return ns.spec(ref.id)
  }

  override const Str name

  override const Dict meta

  override const Spec funcType

  override Obj? doCall(Comp self, Obj? arg)
  {
    throw Err("TODO")
  }
}

