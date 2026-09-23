//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2026  Brian Frank  Creation
//

using util
using xeto

**
** Implementation of SpecSugar
**
@Js
const final class MSugar : SpecSugar
{
  ** Flatten sugar spec to its anchor and effective constraints; mixins
  ** targeting a spec in the sugar chain contribute their constraints
  static MSugar init(Spec spec, Spec[]? mixins := null)
  {
    anchors := anchors(spec)
    if (anchors.size != 1) throw Err("Sugar spec must have one nominal anchor: $spec.qname $anchors")

    acc := Str:Spec[:]
    eachSugar(spec) |x| { addConstraints(acc, x.slotsOwn) }
    mixins?.each |x| { if (x.base.isSugar) addConstraints(acc, x.slotsOwn) }

    sorted := Str:Spec[:] { ordered = true }
    acc.keys.sort.each |n| { sorted[n] = acc[n] }
    return make(anchors.first, SpecMap(sorted))
  }

  ** Nominal bases of the sugar chain reduced to the most specific;
  ** a valid sugar spec has exactly one
  static Spec[] anchors(Spec spec)
  {
    acc := Str:Spec[:] { ordered = true }
    eachSugar(spec) |x| { XetoUtil.eachBase(x) |b| { if (!b.isSugar) acc[b.qname] = b } }
    return XetoUtil.excludeSupertypes(acc.vals)
  }

  ** Walk spec and its sugar ancestors; the walk stops at nominal specs
  static Void eachSugar(Spec x, |Spec| f)
  {
    f(x)
    XetoUtil.eachBase(x) |b| { if (b.isSugar) eachSugar(b, f) }
  }

  ** Constraints are required markers and invariant scalars; other
  ** slots are defaults for instantiation.  Subtypes are walked first
  ** so their constraints win
  private static Void addConstraints(Str:Spec acc, SpecMap slots)
  {
    slots.each |s, n| { if (isConstraint(s) && acc[n] == null) acc[n] = s }
  }

  ** Is slot a required marker or invariant scalar
  static Bool isConstraint(Spec slot)
  {
    slot.isMarker ? !slot.isMaybe : slot.meta.has("invariant")
  }

  private new make(Spec anchor, SpecMap constraints)
  {
    this.anchor = anchor
    this.constraints = constraints
  }

  const override Spec anchor

  const override SpecMap constraints

  override Str toStr() { "$anchor.qname {" + constraints.names.join(", ") + "}" }
}

