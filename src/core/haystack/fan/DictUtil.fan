//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Dec 2009  Brian Frank  Creation
//

using concurrent
using xeto::Link

**************************************************************************
** EmptyDict
**************************************************************************

@Js
internal const class EmptyDict : Dict
{
  static const EmptyDict val := EmptyDict()
  override Bool isEmpty() { true }
  override Obj? get(Str key, Obj? def := null) { def }
  override Bool has(Str name) { false }
  override Bool missing(Str name) { true }
  override Void each(|Obj, Str| f) {}
  override Obj? eachWhile(|Obj, Str->Obj?| f) { null }
  override This map(|Obj, Str->Obj| f) { this }
  override Obj? trap(Str n, Obj?[]? a := null) { throw UnknownNameErr(n) }
}

**************************************************************************
** MapDict
**************************************************************************

@Js
internal const class MapDict : Dict
{
  new make(Str:Obj? tags) { this.tags = tags }
  const Str:Obj? tags
  override Bool isEmpty() { tags.isEmpty }
  override Obj? get(Str n, Obj? def := null) { tags.get(n, def) }
  override Bool has(Str n) { tags.get(n, null) != null }
  override Bool missing(Str n) { tags.get(n, null) == null }
  override Void each(|Obj, Str| f)
  {
    tags.each |v, n|
    {
      if (v != null) f(v, n)
    }
  }
  override Obj? eachWhile(|Obj, Str->Obj?| f)
  {
    tags.eachWhile |v, n|
    {
      v == null ? null : f(v, n)
    }
  }
  override Obj? trap(Str n, Obj?[]? a := null)
  {
    v := tags[n]
    if (v != null) return v
    throw UnknownNameErr(n)
  }
}

**************************************************************************
** NotNullMapDict
**************************************************************************

@Js
internal const class NotNullMapDict : Dict
{
  new make(Str:Obj tags) { this.tags = tags }
  const Str:Obj tags
  override Bool isEmpty() { tags.isEmpty }
  override Obj? get(Str n, Obj? def := null) { tags.get(n, def) }
  override Bool has(Str n) { tags.get(n, null) != null }
  override Bool missing(Str n) { tags.get(n, null) == null }
  override Void each(|Obj, Str| f) { tags.each(f) }
  override Obj? eachWhile(|Obj, Str->Obj?| f) { tags.eachWhile(f) }
  override Obj? trap(Str n, Obj?[]? a := null)
  {
    v := tags[n]
    if (v != null) return v
    throw UnknownNameErr(n)
  }
}

**************************************************************************
** DictX
**************************************************************************

@Js
internal abstract const class DictX : Dict
{
  override final Bool isEmpty() { false }
  override final Bool has(Str name) { get(name, null) != null }
  override final Bool missing(Str name) { get(name, null) == null }
  override final Obj? trap(Str name, Obj?[]? args := null)
  {
    val := get(name, null)
    if (val != null) return val
    throw UnknownNameErr(name)
  }
}

**************************************************************************
** Dict1
**************************************************************************

@Js
internal const class Dict1 : DictX
{
  new make1(Str n0, Obj v0)
  {
    this.n0 = n0; this.v0 = v0
  }

  override Obj? get(Str name, Obj? def := null)
  {
    if (name == n0) return v0
    return def
  }

  override Void each(|Obj,Str| f)
  {
    f(v0,n0)
  }

  override Obj? eachWhile(|Obj,Str->Obj?| f)
  {
    r := null
    r = f(v0,n0); if (r != null) return r
    return null
  }

  override This map(|Obj,Str->Obj| f)
  {
    make1(n0, f(v0, n0))
  }

  const Str n0
  const Obj v0
}

**************************************************************************
** Dict2
**************************************************************************

@Js
internal const class Dict2 : DictX
{
  new make2(Str n0, Obj v0, Str n1, Obj v1)
  {
    this.n0 = n0; this.v0 = v0
    this.n1 = n1; this.v1 = v1
  }

  override Obj? get(Str name, Obj? def := null)
  {
    if (name == n0) return v0
    if (name == n1) return v1
    return def
  }

  override Void each(|Obj,Str| f)
  {
    f(v0,n0)
    f(v1,n1)
  }

  override Obj? eachWhile(|Obj,Str->Obj?| f)
  {
    r := null
    r = f(v0,n0); if (r != null) return r
    r = f(v1,n1); if (r != null) return r
    return null
  }

  override This map(|Obj,Str->Obj| f)
  {
    make2(n0, f(v0, n0),
          n1, f(v1, n1))
  }

  const Str n0
  const Str n1
  const Obj v0
  const Obj v1
}

**************************************************************************
** Dict3
**************************************************************************

@Js
internal const class Dict3 : DictX
{
  new make3(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2)
  {
    this.n0 = n0; this.v0 = v0
    this.n1 = n1; this.v1 = v1
    this.n2 = n2; this.v2 = v2
  }

  override Obj? get(Str name, Obj? def := null)
  {
    if (name == n0) return v0
    if (name == n1) return v1
    if (name == n2) return v2
    return def
  }

  override Void each(|Obj,Str| f)
  {
    f(v0,n0)
    f(v1,n1)
    f(v2,n2)
  }

  override Obj? eachWhile(|Obj,Str->Obj?| f)
  {
    r := null
    r = f(v0,n0); if (r != null) return r
    r = f(v1,n1); if (r != null) return r
    r = f(v2,n2); if (r != null) return r
    return null
  }

  override This map(|Obj,Str->Obj| f)
  {
    make3(n0, f(v0, n0),
          n1, f(v1, n1),
          n2, f(v2, n2))
  }

  const Str n0
  const Str n1
  const Str n2
  const Obj v0
  const Obj v1
  const Obj v2
}

**************************************************************************
** Dict4
**************************************************************************

@Js
internal const class Dict4 : DictX
{
  new make4(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3)
  {
    this.n0 = n0; this.v0 = v0
    this.n1 = n1; this.v1 = v1
    this.n2 = n2; this.v2 = v2
    this.n3 = n3; this.v3 = v3
  }

  override Obj? get(Str name, Obj? def := null)
  {
    if (name == n0) return v0
    if (name == n1) return v1
    if (name == n2) return v2
    if (name == n3) return v3
    return def
  }

  override Void each(|Obj,Str| f)
  {
    f(v0,n0)
    f(v1,n1)
    f(v2,n2)
    f(v3,n3)
  }

  override Obj? eachWhile(|Obj,Str->Obj?| f)
  {
    r := null
    r = f(v0,n0); if (r != null) return r
    r = f(v1,n1); if (r != null) return r
    r = f(v2,n2); if (r != null) return r
    r = f(v3,n3); if (r != null) return r
    return null
  }

  override This map(|Obj,Str->Obj| f)
  {
    make4(n0, f(v0, n0),
          n1, f(v1, n1),
          n2, f(v2, n2),
          n3, f(v3, n3))
  }

  const Str n0
  const Str n1
  const Str n2
  const Str n3
  const Obj v0
  const Obj v1
  const Obj v2
  const Obj v3
}

**************************************************************************
** Dict5
**************************************************************************

@Js
internal const class Dict5 : DictX
{
  new make5(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3, Str n4, Obj v4)
  {
    this.n0 = n0; this.v0 = v0
    this.n1 = n1; this.v1 = v1
    this.n2 = n2; this.v2 = v2
    this.n3 = n3; this.v3 = v3
    this.n4 = n4; this.v4 = v4
  }

  override Obj? get(Str name, Obj? def := null)
  {
    if (name == n0) return v0
    if (name == n1) return v1
    if (name == n2) return v2
    if (name == n3) return v3
    if (name == n4) return v4
    return def
  }

  override Void each(|Obj,Str| f)
  {
    f(v0,n0)
    f(v1,n1)
    f(v2,n2)
    f(v3,n3)
    f(v4,n4)
  }

  override Obj? eachWhile(|Obj,Str->Obj?| f)
  {
    r := null
    r = f(v0,n0); if (r != null) return r
    r = f(v1,n1); if (r != null) return r
    r = f(v2,n2); if (r != null) return r
    r = f(v3,n3); if (r != null) return r
    r = f(v4,n4); if (r != null) return r
    return null
  }

  override This map(|Obj,Str->Obj| f)
  {
    make5(n0, f(v0, n0),
          n1, f(v1, n1),
          n2, f(v2, n2),
          n3, f(v3, n3),
          n4, f(v4, n4))
  }

  const Str n0
  const Str n1
  const Str n2
  const Str n3
  const Str n4
  const Obj v0
  const Obj v1
  const Obj v2
  const Obj v3
  const Obj v4
}

**************************************************************************
** Dict6
**************************************************************************

@Js
internal const class Dict6 : DictX
{
  new make6(Str n0, Obj v0, Str n1, Obj v1, Str n2, Obj v2, Str n3, Obj v3, Str n4, Obj v4, Str n5, Obj v5)
  {
    this.n0 = n0; this.v0 = v0
    this.n1 = n1; this.v1 = v1
    this.n2 = n2; this.v2 = v2
    this.n3 = n3; this.v3 = v3
    this.n4 = n4; this.v4 = v4
    this.n5 = n5; this.v5 = v5
  }

  override Obj? get(Str name, Obj? def := null)
  {
    if (name == n0) return v0
    if (name == n1) return v1
    if (name == n2) return v2
    if (name == n3) return v3
    if (name == n4) return v4
    if (name == n5) return v5
    return def
  }

  override Void each(|Obj,Str| f)
  {
    f(v0,n0)
    f(v1,n1)
    f(v2,n2)
    f(v3,n3)
    f(v4,n4)
    f(v5,n5)
  }

  override Obj? eachWhile(|Obj,Str->Obj?| f)
  {
    r := null
    r = f(v0,n0); if (r != null) return r
    r = f(v1,n1); if (r != null) return r
    r = f(v2,n2); if (r != null) return r
    r = f(v3,n3); if (r != null) return r
    r = f(v4,n4); if (r != null) return r
    r = f(v5,n5); if (r != null) return r
    return null
  }

  override This map(|Obj,Str->Obj| f)
  {
    make6(n0, f(v0, n0),
          n1, f(v1, n1),
          n2, f(v2, n2),
          n3, f(v3, n3),
          n4, f(v4, n4),
          n5, f(v5, n5))
  }

  const Str n0
  const Str n1
  const Str n2
  const Str n3
  const Str n4
  const Str n5
  const Obj v0
  const Obj v1
  const Obj v2
  const Obj v3
  const Obj v4
  const Obj v5
}

**************************************************************************
** WrapDict
**************************************************************************

@NoDoc @Js
abstract const class WrapDict : Dict
{
  new make(Dict wrapped) { this.wrapped = normalize(wrapped) }
  const Dict wrapped
  @Operator override Obj? get(Str n, Obj? def := null) { wrapped.get(n, def) }
  override Bool isEmpty() { wrapped.isEmpty }
  override Bool has(Str n) { wrapped.has(n) }
  override Bool missing(Str n) { wrapped.missing(n) }
  override Void each(|Obj, Str| f) { wrapped.each(f) }
  override Obj? eachWhile(|Obj, Str->Obj?| f) { wrapped.eachWhile(f) }
  override Obj? trap(Str n, Obj?[]? a := null) { wrapped.trap(n, a) }
  virtual Dict normalize(Dict d) { d }
}

**************************************************************************
** ReflectDict
**************************************************************************

**
** Dict that defines its tags as fields
**
@NoDoc @Js
abstract const class ReflectDict : Dict
{
  override Bool isEmpty() { false }

  override Bool has(Str n) { get(n, null) != null }

  override Bool missing(Str n) { get(n, null) == null }

  override Obj? get(Str n, Obj? def := null)
  {
    field := typeof.field(n, false)
    if (field != null && !field.isStatic) return field.get(this) ?: def
    return def
  }

  override Void each(|Obj val, Str name| f)
  {
    typeof.fields.each |field|
    {
      if (field.isStatic) return
      val := field.get(this)
      if (val == null) return
      f(val, field.name)
    }
  }

  override Obj? eachWhile(|Obj val, Str name->Obj?| f)
  {
    typeof.fields.eachWhile |field|
    {
      if (field.isStatic) return null
      val := field.get(this)
      if (val == null) return null
      return f(val, field.name)
    }
  }

  override Obj? trap(Str n, Obj?[]? args := null)
  {
    v := get(n, null)
    if (v != null) return v
    throw UnknownNameErr(n)
  }
}

**************************************************************************
** MLink
**************************************************************************

@Js
internal const class MLink : WrapDict, xeto::Link
{
  static once Ref specRef() { Ref("sys.comp::Link") }
  new make(Dict wrapped) : super(wrapped)
  {
    this.fromRef  = wrapped["fromRef"]  as Ref ?: Ref.nullRef
    this.fromSlot = wrapped["fromSlot"] as Str ?: "-"
  }
  override This map(|Obj, Str->Obj| f) { make(wrapped.map(f)) }
  override const Ref fromRef
  override const Str fromSlot
}

**************************************************************************
** MLinks
**************************************************************************

@Js
internal const class MLinks : WrapDict, xeto::Links
{
  static once Ref specRef() { Ref("sys.comp::Links") }
  static once MLinks empty() { make(Etc.dict1("spec", specRef)) }

  new make(Dict wrapped) : super(wrapped) {}

  override This map(|Obj, Str->Obj| f) { make(wrapped.map(f)) }

  override Bool isLinked(Str toSlot)
  {
    has(toSlot)
  }

  override Void eachLink(|Str,Link| f)
  {
    each |v, n|
    {
      if (v is Link)
      {
        f(n, v)
      }
      else if (v is List)
      {
        ((List)v).each |x| { if (x is Link) f(n, x) }
      }
    }
  }

  override Link[] listOn(Str toSlot)
  {
    v := get(toSlot)
    if (v is List) return v
    if (v is Link) return Link[v]
    return Link#.emptyList
  }

  override This add(Str toSlot, Link newLink)
  {
    acc := Etc.dictToMap(this)
    old := acc[toSlot]
    if (old == null)
    {
      acc[toSlot] = newLink
    }
    else if (old is Link)
    {
      oldLink := (Link)old
      if (eq(oldLink, newLink)) return this
      acc[toSlot] = [oldLink, newLink]
    }
    else
    {
      oldList := (List)old
      dup := oldList.find |x| { eq(x, newLink) }
      if (dup != null) return this
      acc[toSlot] = oldList.dup.add(newLink)
    }
    return make(Etc.dictFromMap(acc))
  }

  override This remove(Str toSlot, Link link)
  {
    acc := Etc.dictToMap(this)
    old := acc[toSlot]
    if (old == null) return this

    if (old is Link)
    {
      if (!eq(old, link)) return this
      acc.remove(toSlot)
    }
    else
    {
      oldList := (List)old
      idx := oldList.findIndex |x| { eq(x, link) }
      if (idx == null) return this
      newList := oldList.dup
      newList.removeAt(idx)
      if (newList.isEmpty) acc.remove(toSlot)
      else acc[toSlot] = newList
    }
    if (acc.size == 1 && acc["spec"] != null) return empty
    return make(Etc.dictFromMap(acc))
  }

  private static Bool eq(Link a, Link b)
  {
    a.fromRef == b.fromRef && a.fromSlot == b.fromSlot
  }
}

**************************************************************************
** DictHashKey
**************************************************************************

@NoDoc @Js
const class DictHashKey
{
  new make(Dict dict)
  {
    // compute size and hash code of key/values (must be independent of ordering)
    hash := 17
    size := 0
    nameHash := 0
    valHash := 0
    dict.each |v, n|
    {
      if (v is Dict || v is Grid || v is List) return

      nh := n.hash; nameHash += nh
      vh := v.hash; valHash += vh

      hash += (nh + vh)
      size++
    }

    this.dict     = dict
    this.nameHash = nameHash
    this.valHash  = valHash
    this.hash     = hash
    this.size     = size
  }

  const Dict dict
  const Int size
  const Int nameHash
  const Int valHash

  const override Int hash

  override Str toStr() { "DictHashKey {$dict}" }

  override Bool equals(Obj? that)
  {
    x := that as DictHashKey
    if (x == null) return false

    if (size != x.size ||
        nameHash != x.nameHash ||
        valHash != x.valHash) return false

    v := dict.eachWhile |v, n|
    {
      if (v is Dict || v is Grid || v is List) return null
      if (x.dict[n] != v) return false
      return null
    }
    if (v != null) return false
    return true
  }

}

