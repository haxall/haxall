//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Nov 2024  Brian Frank  Creation
//

using util
using xeto

**
** Implementation of SpecChoice
**
@Js
const final class MChoice : SpecChoice
{
  internal new make(LibNamespace ns, XetoSpec spec)
  {
    if (!spec.isChoice) throw UnsupportedErr("Spec is not choice: $spec.qname")
    this.ns            = ns
    this.spec          = spec
    this.type          = spec.type
    this.isMaybe       = spec.isMaybe
    this.isMultiChoice = spec.meta.has("multiChoice")
  }

  const LibNamespace ns

  override const Spec spec

  override const Spec type

  override const Bool isMaybe

  override const Bool isMultiChoice

  override Spec[] selections(Dict instance, Bool checked := true)
  {
    acc := Spec[,]
    ns.eachType |x|
    {
      if (!x.isa(type)) return
      if (x.slots.isEmpty) return
      if (hasChoiceMarkers(instance, x)) acc.add(x)
    }

    // TODO: for now just compare on number of tags so that {hot, water}
    // trumps {water}. But that isn't correct because {naturalGas, hot, water}
    // would actually be incorrect with multiple matches
    if (acc.size > 1)
    {
      maxSize := 0
      acc.each |XetoSpec x| { maxSize = maxSize.max(x.m.slots.size) }
      acc = acc.findAll |XetoSpec x->Bool| { x.m.slots.size == maxSize }
    }

    // if not checked then return list
    if (!checked) return acc

    // check for size
    if (acc.size == 1)
    {
      return acc
    }
    else if (acc.size == 0)
    {
      if (isMaybe) return acc
      else throw Err("Choice not implemented by instance: $type")
    }
    else
    {
      if (isMultiChoice) return acc
      else throw Err("Multiple choices implemented by instance: $type $acc")
    }
  }

  override Spec? selection(Dict instance, Bool checked := true)
  {
    selections(instance, checked).first
  }

  ** Return if instance has all the given tags of the given choice
  static Bool hasChoiceMarkers(Dict instance, Spec choice)
  {
    r := choice.slots.eachWhile |slot|
    {
      instance.has(slot.name) ? null : "break"
    }
    return r == null
  }
}

