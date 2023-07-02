//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jan 2023  Brian Frank  Creation
//

using util
using xeto

**
** Implementation of Lib wrapped by XetoLib
**
@Js
internal const final class MLib : MSpec
{
  new make(MEnv env, FileLoc loc, Str qname, XetoType libType, Dict meta, MSlots slots, Version version, MLibDepend[] depends)
    : super(loc, null, qname, libType, libType, meta, meta, slots, slots, 0)
  {
    this.env     = env
    this.qname   = qname
    this.version = version
    this.depends = depends

    types := Spec[,]
    slots.each |x| { types.add(x) }
    this.types = types
  }

  const override MEnv env

  const override Str qname

  const Spec[] types

  override Spec spec() { env.sys.lib }

  const Version version

  const LibDepend[] depends

  Spec? libType(Str name, Bool checked := true)
  {
    type := slotOwn(name, false)
    if (type != null) return type
    if (checked) throw UnknownTypeErr(qname + "::" + name)
    return null
  }

  override Bool isLib() { true }

  override Str toStr() { qname }

}

**************************************************************************
** XetoLib
**************************************************************************

**
** XetoLib is the referential proxy for MLib
**
@Js
internal const class XetoLib : XetoSpec, Lib
{
  new make() : super() {}

  override XetoLib lib() { this }

  override Spec[] types() { ml.types }

  override Version version() { ml.version }

  override LibDepend[] depends() { ml.depends }

  override Spec? libType(Str name, Bool checked := true) { ml.libType(name, checked) }

  const MLib? ml
}

**************************************************************************
** MLibDepend
**************************************************************************

**
** Implementation for LibDepend
**
@Js
internal const class MLibDepend : LibDepend
{
  new make(Str qname, MLibDependVersions versions, FileLoc loc)
  {
    this.qname = qname
    this.versions = versions
    this.loc = loc
  }

  const override Str qname
  const override MLibDependVersions versions
  override Str toStr() { "$qname $versions" }
  const FileLoc loc
}

**************************************************************************
** MLibDependVersions
**************************************************************************

**
** Implementation for LibDependVersions
**
@Js
internal const class MLibDependVersions : LibDependVersions
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



