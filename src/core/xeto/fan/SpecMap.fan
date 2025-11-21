//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Feb 2023  Brian Frank  Creation
//

**
** SpecMap is a map of named Specs
**
** NOTE: in most cases name keys match the 'Spec.name' of slot specs
** themselves. However, in cases where the slot name is an auto-name
** of "_0", "_1", etc its possible that the slot name keys do **not** match
** their slot names.  This occurs when inheriting auto-named slots.  The
** spec names are assigned uniquely per type, but when merged by inheritance
** might be assigned new unique names. This often occurs in queries such as
** point queries.
**
@Js
const mixin SpecMap
{
  ** Empty spec map
  static SpecMap empty() { EmptySpecMap.val }

  ** Factory
  static new make(Str:Spec map)
  {
    map.isEmpty ? empty : MSpecMap.makeMap(map)
  }

  ** Return if slots are empty
  abstract Bool isEmpty()

  ** Return if the given slot name is defined.
  ** NOTE: the name key may not match slot name
  abstract Bool has(Str name)

  ** Return if the given slot name is undefined.
  ** NOTE: the name key may not match slot name
  abstract Bool missing(Str name)

  ** Get the child slot spec as keyed by this slots map
  ** NOTE: the name key may not match slot name
  abstract Spec? get(Str name, Bool checked := true)

  ** Convenience to list the slots names; prefer `each`.
  ** NOTE: the names may not match slots names
  abstract Str[] names()

  ** Iterate through the children using key.
  ** NOTE: the name parameter may not match slots names
  abstract Void each(|Spec, Str| f)

  ** Iterate through the children until function returns non-null
  ** NOTE: the name parameter may not match slots names
  abstract Obj? eachWhile(|Spec, Str->Obj?| f)

  ** Number of specs
  @NoDoc abstract Int size()

  ** Get the slots as Dict of the specs.
  @NoDoc abstract Dict toDict()

}

**************************************************************************
** EmptySpecMap
**************************************************************************

@Js
internal final const class EmptySpecMap : SpecMap
{
  static const EmptySpecMap val := make

  private new make() {}

  override Int size() { 0 }

  override Bool isEmpty() { true }

  override Bool has(Str name) { false }

  override Bool missing(Str name) { true }

  override Spec? get(Str name, Bool checked := true)
  {
    if (!checked) return null
    throw UnknownSpecErr(name)
  }

  override Str[] names() { Str#.emptyList }

  override Void each(|Spec,Str| f) {}

  override Obj? eachWhile(|Spec,Str->Obj?| f) { null }

  override Str toStr() { "{}" }

  override Dict toDict() { MSlotsDict(this) }
}

**************************************************************************
** MSpecMap
**************************************************************************

@Js
internal final const class MSpecMap : SpecMap
{
  new makeMap(Str:Spec map) { this.map = map }

  const Str:Spec map

  override Int size() { map.size }

  override Bool isEmpty()
  {
    map.isEmpty
  }

  override Bool has(Str name)
  {
    map.containsKey(name)
  }

  override Bool missing(Str name)
  {
    !map.containsKey(name)
  }

  override Spec? get(Str name, Bool checked := true)
  {
    kid := map.get(name)
    if (kid != null) return kid
    if (!checked) return null
    throw UnknownSpecErr(name)
  }

  override Str[] names()
  {
    acc := Str[,]
    acc.capacity = map.size
    map.each |v, n| { acc.add(n) }
    return acc
  }

  override Void each(|Spec,Str| f)
  {
    map.each(f)
  }

  override Obj? eachWhile(|Spec,Str->Obj?| f)
  {
    map.eachWhile(f)
  }

  override Str toStr()
  {
    s := StrBuf()
    s.add("{")
    each |slot|
    {
      if (s.size > 1) s.add(", ")
      s.add(slot.name)
    }
    return s.add("}").toStr
  }

  override Dict toDict()
  {
    MSlotsDict(this)
  }
}

**************************************************************************
** MSlotsDict
**************************************************************************

@Js
internal const class MSlotsDict : Dict
{
  new make(SpecMap wrap) { this.wrap = wrap }
  const SpecMap wrap
  @Operator override Obj? get(Str n) { wrap.get(n, false) }
  override Bool isEmpty() { wrap.isEmpty }
  override Bool has(Str n) { wrap.get(n, false) != null }
  override Bool missing(Str n) { wrap.get(n, false) == null }
  override Void each(|Obj, Str| f) { wrap.each(f) }
  override Obj? eachWhile(|Obj, Str->Obj?| f) { wrap.eachWhile(f) }
  override Obj? trap(Str n, Obj?[]? a := null) { wrap.get(n, true) }
}

