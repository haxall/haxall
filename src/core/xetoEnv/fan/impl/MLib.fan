//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jan 2023  Brian Frank  Creation
//

using util
using xeto
using haystack::UnknownSpecErr

**
** Implementation of Lib wrapped by XetoLib
**
@Js
const final class MLib
{
  new make(MEnv env, FileLoc loc, Int nameCode, MNameDict meta, Version version, MLibDepend[] depends, Str:Spec typesMap, Str:Dict instancesMap)
  {
    this.env          = env
    this.loc          = loc
    this.nameCode     = nameCode
    this.name         = env.names.toName(nameCode)
    this.id           = haystack::Ref(StrBuf(4+name.size).add("lib:").add(name).toStr, null)
    this.meta         = meta
    this.version      = version
    this.depends      = depends
    this.typesMap     = typesMap
    this.instancesMap = instancesMap
  }

  const MEnv env

  const FileLoc loc

  const Ref id

  const Int nameCode

  const Str name

  const MNameDict meta

  const Version version

  const LibDepend[] depends

  const Str:Spec typesMap

  const Str:Dict instancesMap

  once Spec[] types()
  {
    if (typesMap.isEmpty)
      return Spec#.emptyList
    else
      return typesMap.vals.sort |a, b| { a.name <=> b.name }.toImmutable
  }

  Spec? type(Str name, Bool checked := true)
  {
    type := typesMap[name]
    if (type != null) return type
    if (checked) throw UnknownSpecErr(this.name + "::" + name)
    return null
  }

  once Dict[] instances()
  {
    if (instancesMap.isEmpty)
      return Dict#.emptyList
    else
      return instancesMap.vals.sort |a, b| { a->id <=> b->id }.toImmutable
  }

  Dict? instance(Str name, Bool checked := true)
  {
    instance := instancesMap[name]
    if (instance != null) return instance
    if (checked) throw haystack::UnknownRecErr(this.name + "::" + name)
    return null
  }

  override Str toStr() { name }

//////////////////////////////////////////////////////////////////////////
// Dict Representation
//////////////////////////////////////////////////////////////////////////

  Obj? get(Str name, Obj? def := null)
  {
    if (name == "id")     return id
    if (name == "spec")   return env.libSpecRef
    if (name == "loaded") return env.marker
    return meta.get(name, def)
  }

  Bool has(Str name)
  {
    if (name == "id")     return true
    if (name == "spec")   return true
    if (name == "loaded") return true
    return meta.has(name)
  }

  Bool missing(Str name)
  {
    if (name == "id")     return false
    if (name == "spec")   return false
    if (name == "loaded") return false
    return meta.missing(name)
  }

  Void each(|Obj val, Str name| f)
  {
    f(id,             "id")
    f(env.libSpecRef, "spec")
    f(env.marker,     "loaded")
    meta.each(f)
  }

  Obj? eachWhile(|Obj val, Str name->Obj?| f)
  {
    r := f(id, "id");               if (r != null) return r
    r  = f(env.libSpecRef, "spec"); if (r != null) return r
    r  = f(env.marker, "loaded");   if (r != null) return r
    return meta.eachWhile(f)
  }

  override Obj? trap(Str name, Obj?[]? args := null)
  {
    val := get(name, null)
    if (val != null) return val
    return meta.trap(name, args)
  }

}

**************************************************************************
** XetoLib
**************************************************************************

**
** XetoLib is the referential proxy for MLib
**
@Js
const final class XetoLib : Lib, haystack::Dict
{
  override FileLoc loc() { m.loc }

  override XetoEnv env() { m.env }

  override haystack::Ref id() { m.id }

  override haystack::Ref _id() { m.id }

  override Str name() { m.name }

  override Dict meta() { m.meta }

  override Version version() { m.version }

  override LibDepend[] depends() { m.depends }

  override Spec[] types() { m.types }

  override Spec? type(Str name, Bool checked := true) { m.type(name, checked) }

  override Dict[] instances() { m.instances }

  override Dict? instance(Str name, Bool checked := true) { m.instance(name, checked) }

  override final Bool isEmpty() { false }

  @Operator override final Obj? get(Str n, Obj? d := null) { m.get(n, d) }

  override final Bool has(Str n) { m.has(n) }

  override final Bool missing(Str n) { m.missing(n) }

  override final Void each(|Obj val, Str name| f) { m.each(f) }

  override final Obj? eachWhile(|Obj,Str->Obj?| f) { m.eachWhile(f) }

  override final Obj? trap(Str n, Obj?[]? a := null) { m.trap(n, a) }

  const MLib? m
}

**************************************************************************
** MLibDepend
**************************************************************************

**
** Implementation for LibDepend
**
@Js
const class MLibDepend : LibDepend
{
  new make(Str name, MLibDependVersions versions, FileLoc loc)
  {
    this.name = name
    this.versions = versions
    this.loc = loc
  }

  const override Str name
  const override MLibDependVersions versions
  override Str toStr() { "$name $versions" }
  const FileLoc loc
}

**************************************************************************
** MLibDependVersions
**************************************************************************

**
** Implementation for LibDependVersions
**
@Js
const class MLibDependVersions : LibDependVersions
{
  static new fromStr(Str s, Bool checked)
  {
    try
    {
      dash := s.index("-")
      if (dash == null)
      {
        a := s.split('.', false)
        if (a.size != 3) throw Err()
        return makeWildcard(parseSeg(a[0]), parseSeg(a[1]), parseSeg(a[2]))
      }
      else
      {
        a := s[0..<dash].trimEnd.split('.', false)
        b := s[dash+1..-1].trimStart.split('.', false)
        if (a.size != 3 || b.size != 3) throw Err()
        return makeRange(parseSeg(a[0]), parseSeg(a[1]), parseSeg(a[2]),
                         parseSeg(b[0]), parseSeg(b[1]), parseSeg(b[2]))
      }
    }
    catch (Err e)
    {
      if (checked) throw ParseErr(s)
      return null
    }
  }

  static const MLibDependVersions wildcard := makeWildcard(-1, -1, -1)

  private static Int parseSeg(Str s) { s == "x" ? -1 : s.toInt(10, true) }

  new makeWildcard(Int a0, Int a1, Int a2)
  {
    this.isRange = false
    this.a0 = a0; this.a1 = a1; this.a2 = a2
  }

  new makeRange(Int a0, Int a1, Int a2, Int b0, Int b1, Int b2)
  {
    this.isRange = true
    this.a0 = a0; this.a1 = a1; this.a2 = a2
    this.b0 = b0; this.b1 = b1; this.b2 = b2
  }

  override Bool contains(Version v)
  {
    // false if less then 3 segments
    segs := v.segments
    if (segs.size < 3) return false
    v0 := segs[0]; v1 := segs[1]; v2 := segs[2]

    // if end is wildcard, then each segment must be equal or x
    if (!isRange) return eq(v0, a0) && eq(v1, a1) && eq(v2, a2)

    // ensure v is greater than or equal to a
    if (lt(v0, a0)) return false
    if (eq(v0, a0))
    {
      if (lt(v1, a1)) return false
      if (eq(v1, a1))
      {
        if (lt(v2, a2)) return false
      }
    }

    // ensure v is less than or equal to b
    if (gt(v0, b0)) return false
    if (eq(v0, b0))
    {
      if (gt(v1, b1)) return false
      if (eq(v1, b1))
      {
        if (gt(v2, b2)) return false
      }
    }

    return true
  }

  private static Bool eq(Int actual, Int constraint)
  {
    if (constraint < 0) return true
    return actual == constraint
  }

  private static Bool gt(Int actual, Int constraint)
  {
    if (constraint < 0) return false
    return actual > constraint
  }

  private static Bool lt(Int actual, Int constraint)
  {
    if (constraint < 0) return false
    return actual < constraint
  }

  const Bool isRange
  const Int a0  // start major
  const Int a1  // start minor
  const Int a2  // start patch
  const Int b0  // end major
  const Int b1  // end minor
  const Int b2  // end patch

  override Str toStr()
  {
    s := StrBuf()
      .add(a0 < 0 ? "x" : a0.toStr).addChar('.')
      .add(a1 < 0 ? "x" : a1.toStr).addChar('.')
      .add(a2 < 0 ? "x" : a2.toStr)
    if (!isRange) return s.toStr
    s.add("-")
     .add(b0 < 0 ? "x" : b0.toStr).addChar('.')
     .add(b1 < 0 ? "x" : b1.toStr).addChar('.')
     .add(b2 < 0 ? "x" : b2.toStr)
    return s.toStr
  }

}



