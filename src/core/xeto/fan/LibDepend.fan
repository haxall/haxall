//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Apr 2024  Brian Frank  Pull out of Lib.fan
//

using util

**
** Xeto library dependency as name and version constraints
**
@Js
const mixin LibDepend : Dict
{
  ** Construct with name and version constraints
  static new make(Str name, LibDependVersions versions := LibDependVersions.wildcard)
  {
    Slot.findMethod("xetom::MLibDepend.makeFields").call(name, versions, FileLoc.unknown)
  }

  ** Construct from exact LibVersion
  static new makeExact(LibVersion v)
  {
    make(v.name, LibDependVersions(v.version))
  }

  ** Library dotted name
  abstract Str name()

  ** Version constraints that satisify this dependency
  abstract LibDependVersions versions()

  ** String representation is "<qname> <versions>"
  abstract override Str toStr()
}

**************************************************************************
** LibDependVersions
**************************************************************************

**
** Xeto library dependency version constraints.  The format is:
**
**   <range>    :=  <ver> "-" <ver>
**   <ver>      :=  <seg> "." <seg> "." <seg>
**   <seg>      :=  <wildcard> | <number>
**   <wildcard> :=  "x"
**   <number>   :=  <digit>+
**   <digit>    :=  "0" - "9"
**
** Examples:
**   1.2.3         // version 1.2.3 exact
**   1.2.x         // any version that starts with "1.2."
**   3.x.x         // any version that starts with "3."
**   1.0.0-2.0.0   // range from 1.0.0 to 2.0.0 inclusive
**   1.2.0-1.3.x   // range from 1.2.0 to 1.3.* inclusive
**
@Js
const mixin LibDependVersions
{
  ** Constant for "x.x.x"
  static LibDependVersions wildcard()
  {
    MLibDependVersions.wildcardRef
  }

  ** Parse string representation
  static new fromStr(Str s, Bool checked := true)
  {
    MLibDependVersions.fromStr(s, checked)
  }

  ** Create exact match for given version
  static new fromVersion(Version v)
  {
    MLibDependVersions.makeWildcard(v.major, v.minor, v.build)
  }

  ** Map from Fantom depend syntax
  @NoDoc static new fromFantomDepend(Depend d)
  {
    if (d.isSimple)
    {
      v := d.version(0)
      return fromStr("" + v.major + "." + (v.minor ?: "x") +"." +(v.build ?: "x"))
    }
    else
    {
      throw Err("TODO: $d")
    }
  }

  ** Return if the given version satisifies this instance's constraints
  abstract Bool contains(Version version)
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
  static new fromStr(Str s, Bool checked := true)
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

  static const MLibDependVersions wildcardRef := makeWildcard(-1, -1, -1)

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

  override Int hash()
  {
    toStr.hash
  }

  override Bool equals(Obj? that)
  {
    that is MLibDependVersions && this.toStr == that.toStr
  }

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

