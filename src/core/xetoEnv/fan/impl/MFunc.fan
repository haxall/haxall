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
const final class MFunc : SpecFunc
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

  private new make(Spec spec, Spec[] params, Spec returns)
  {
    this.spec = spec
    this.params = params
    this.returns = returns
  }

  const Spec spec

  override const Spec[] params

  override const Spec returns

  override Int arity() { params.size }

  override Obj? api(Bool checked := true)
  {
    // if cached already
    if (apiRef != null) return apiRef

    // attempt to parse/reflect
    api := ApiBindings.cur.load(spec)
    if (api != null)
    {
      // must be ok if dups by multiple threads
      MFunc#apiRef->setConst(this, api)
      return api
    }

    // not found
    if (checked) throw UnsupportedErr("Func not avail as API: $spec.qname")
    return null
  }
  private const Obj? apiRef

  override Obj? axon(Bool checked := true)
  {
    // if cached already
    if (axonRef != null) return axonRef

    // attempt to parse/reflect
    fn := axonPlugin.parse(spec)
    if (fn != null)
    {
      // must be ok if dups by multiple threads
      MFunc#axonRef->setConst(this, fn)
      return fn
    }

    // not found
    if (checked) throw UnsupportedErr("Func not avail in Axon: $spec.qname")
    return null
  }
  private const Obj? axonRef

  static once XetoAxonPlugin axonPlugin()
  {
    Type.find("axon::XetoPlugin").make
  }
}

