//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Dec 2009  Brian Frank  Creation
//

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
  override Obj? trap(Str n, Obj?[]? a := null) { throw UnknownNameErr(n) }
}

**************************************************************************
** MapDict
**************************************************************************

@Js
internal const class MapDict : Dict
{
  new make(Str:Obj? map) { this.map = map }
  const Str:Obj? map
  override Bool isEmpty() { map.isEmpty }
  override Obj? get(Str n, Obj? def := null) { map.get(n, def) }
  override Bool has(Str n) { map.get(n, null) != null }
  override Bool missing(Str n) { map.get(n, null) == null }
  override Void each(|Obj, Str| f)
  {
    map.each |v, n|
    {
      if (v != null) f(v, n)
    }
  }
  override Obj? eachWhile(|Obj, Str->Obj?| f)
  {
    map.eachWhile |v, n|
    {
      v == null ? null : f(v, n)
    }
  }
  override Obj? trap(Str n, Obj?[]? a := null)
  {
    v := map[n]
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
  new make(Str:Obj map) { this.map = map }
  const Str:Obj map
  override Bool isEmpty() { map.isEmpty }
  override Obj? get(Str n, Obj? def := null) { map.get(n, def) }
  override Bool has(Str n) { map.get(n, null) != null }
  override Bool missing(Str n) { map.get(n, null) == null }
  override Void each(|Obj, Str| f) { map.each(f) }
  override Obj? eachWhile(|Obj, Str->Obj?| f) { map.eachWhile(f) }
  override Obj? trap(Str n, Obj?[]? a := null)
  {
    v := map[n]
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
  abstract Dict wrapped()
  @Operator override Obj? get(Str n, Obj? def := null) { wrapped.get(n, def) }
  override Bool isEmpty() { wrapped.isEmpty }
  override Bool has(Str n) { wrapped.has(n) }
  override Bool missing(Str n) { wrapped.missing(n) }
  override Void each(|Obj, Str| f) { wrapped.each(f) }
  override Obj? eachWhile(|Obj, Str->Obj?| f) { wrapped.eachWhile(f) }
  override Obj? trap(Str n, Obj?[]? a := null) { wrapped.trap(n, a) }
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


