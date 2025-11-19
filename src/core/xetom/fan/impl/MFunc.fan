//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Feb 2025  Brian Frank  Creation
//

using util
using xeto

**
** Top level function
**
@Js
const final class MTopFunc : MSpec
{
  new make(MSpecInit init) : super(init)
  {
    this.lib   = init.lib
    this.qname = init.qname
    this.id    = Ref(qname, null)
  }

  const override XetoLib lib

  const override Str qname

  const override Ref id

  override SpecFlavor flavor() { SpecFlavor.func }

  override Str toStr() { qname }
}

**************************************************************************
** MFunc
**************************************************************************

**
** Implementation of SpecFunc
**
@Js
const class MFunc : SpecFunc
{
  static MFunc init(Spec spec)
  {
    Spec? returns
    params := Spec[,]
    spec.slots.each |slot|
    {
      if (slot.name == "returns")
        returns = slot
      else
        params.add(slot)
    }
    return make(spec, params, returns)
  }

  internal new make(Spec spec, Spec[] params, Spec returns)
  {
    this.spec = spec
    this.params = params
    this.returns = returns
  }

  const Spec spec

  override const Spec[] params

  override const Spec returns

  override Int arity() { params.size }

  override Thunk thunk() { thunkRef ?: initThunk }
  private const Thunk? thunkRef

  override Bool hasThunk() { thunkRef != null }

  override Bool isTemplate()
  {
    for (Spec? p := spec; p != null; p = p.base)
      if (p.qname == "sys.template::Template") return true
    return false
  }

  Void setThunk(Thunk thunk)
  {
    #thunkRef->setConst(this, thunk)
  }

  private Thunk initThunk()
  {
    thunk := SpecBindings.cur.thunk(spec)
    setThunk(thunk)
    return thunk
  }
}

