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

  override Str qname()
  {
    XetoUtil.qname(spec.lib.name, spec.name)
  }

  override Bool isFileReturn() { returns.type.isFile }

  override Bool isFileParam() { params.size == 1 && params.first.type.isFile }

  override Str signature()
  {
    s := StrBuf().addChar('(')
    params.each |p, i|
    {
      if (i > 0) s.add(", ")
      s.add(p.name).add(": ").add(p.type.name)
      if (p.metaOwn.has("maybe")) s.addChar('?')
      def := p.metaOwn["val"]
      if (def != null) s.add(" = ").add(def)
    }
    s.add(") -> ").add(returns.type.name)
    return s.toStr
  }
}

