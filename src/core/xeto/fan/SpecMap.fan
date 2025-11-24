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

  ** Factory for map
  @NoDoc static new makeMap(Str:Spec map)
  {
    map.isEmpty ? empty : MapSpecMap.makeMap(map)
  }

  ** Factory for list of maps - each one must be non-empty, nor duplicate names
  @NoDoc static new makeList(SpecMap[] list)
  {
    if (list.isEmpty) return empty
    if (list.size == 1) return list.first
    acc := Str:Spec[:]
    acc.ordered = true
    list.each |x|
    {
      if (x.isEmpty) throw ArgErr("Cannot pass empty map")
      x.each |s, n| { acc.add(n, s) }
    }
    return makeMap(acc)
  }

  ** Factory to chain a and b; names in a override names in b
  @NoDoc static new makeChain(SpecMap a, SpecMap b)
  {
    if (a.isEmpty) return b
    if (b.isEmpty) return a
    return ChainSpecMap(a, b)
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

  ** Return size if available, raise exception for chained maps
  @NoDoc abstract Int size()

  ** Get the slots as Dict of the specs.
  @NoDoc abstract Dict toDict()

}

**************************************************************************
** EmptySpecMap
**************************************************************************

@Js
internal const class EmptySpecMap : SpecMap
{
  static const EmptySpecMap val := make

  private new make() {}

  override Bool isEmpty() { true }

  override Int size() { 0 }

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

  override Dict toDict() { SpecMapDict(this) }
}

**************************************************************************
** NonEmptySpecMap
**************************************************************************

@Js
internal abstract const class NonEmptySpecMap : SpecMap
{
  override final Bool isEmpty() { false }

  override final Bool has(Str name) { get(name, false) != null }

  override final Bool missing(Str name) { get(name, false) == null }

  override final Str[] names()
  {
    acc := Str[,]
    each |v, n| { acc.add(n) }
    return acc
  }

  override final Str toStr()
  {
    s := StrBuf()
    s.add("{")
    each |slot, name|
    {
      if (s.size > 1) s.add(", ")
      s.add(name)
    }
    return s.add("}").toStr
  }

  override final Dict toDict() { SpecMapDict(this) }
}

**************************************************************************
** MapSpecMap
**************************************************************************

@Js
internal final const class MapSpecMap : NonEmptySpecMap
{
  new makeMap(Str:Spec map)
  {
    if (map.isEmpty) throw ArgErr("Cannot use with empty map")
    this.map = map
  }

  const Str:Spec map

  override Int size() { map.size }

  override Spec? get(Str name, Bool checked := true)
  {
    kid := map.get(name)
    if (kid != null) return kid
    if (!checked) return null
    throw UnknownSpecErr(name)
  }

  override Void each(|Spec,Str| f) { map.each(f) }

  override Obj? eachWhile(|Spec,Str->Obj?| f) { map.eachWhile(f) }
}

**************************************************************************
** ChainSpecMap
**************************************************************************

@Js
internal final const class ChainSpecMap : NonEmptySpecMap
{
  new makeMap(SpecMap a, SpecMap b) { this.a = a; this.b = b }

  const SpecMap a  // overrides names in b

  const SpecMap b  // base inherited by a

  override Int size() { throw UnsupportedErr() }

  override Spec? get(Str name, Bool checked := true)
  {
    a.get(name, false) ?: b.get(name, checked)
  }

  override Void each(|Spec,Str| f)
  {
    a.each(f)
    b.each |s, n|
    {
      if (a.has(n)) return
      f(s, n)
    }
  }

  override Obj? eachWhile(|Spec,Str->Obj?| f)
  {
    r := a.eachWhile(f)
    if (r != null) return r
    return b.eachWhile |s, n|
    {
      if (a.has(n)) return null
      return f(s, n)
    }
  }
}

**************************************************************************
** SpecMapDict
**************************************************************************

@Js
internal const class SpecMapDict : Dict
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

