//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Sep 2026  Brian Frank  Split from InheritSpecs
//

using util
using xeto
using xetom
using haystack

**
** Base class for InheritBase and InheritSlots that compute flags
**
@Js
internal abstract class InheritFlags : Step
{
  ** Compute the effective flags which is bitmask used for
  ** fast access of key types in my inheritance hiearchy
  Void inheritFlags(ASpec x)
  {
    if (isSys)
      x.flags = computeFlagsSys(x)
    else if (isSysComp)
      x.flags = computeFlagsSysComp(x)
    else
      x.flags = computeFlagsNonSys(x)
  }

  private Int computeFlagsNonSys(ASpec x)
  {
    // start off with my base type flags that are inherited
    flags := x.base.flags.and(MSpecFlags.inheritMask)

    // global is both flavor and flag so we can use one MSpec; a global
    // has no containing type to be required of, so maybe is implied
    if (x.isGlobal) flags = flags.or(MSpecFlags.global).or(MSpecFlags.maybe)

    // merge in my own meta flags
    if (x.ast.meta != null)
    {
      flags = setMetaFlag(flags, x, "maybe",     MSpecFlags.maybe)
      flags = setMetaFlag(flags, x, "transient", MSpecFlags.transient)
      flags = setMetaFlag(flags, x, "output",    MSpecFlags.output)
    }

    // if my base is compound type; And compounds also
    // inherit entity/comp from their ofs
    if (x.isAnd)
    {
      flags = flags.or(MSpecFlags.and)
      x.ofs(false)?.each |of|
      {
        if (of.isComp)   flags = flags.or(MSpecFlags.comp)
        if (of.isEntity) flags = flags.or(MSpecFlags.entity)
      }
    }
    else if (x.isOr)
    {
      flags = flags.or(MSpecFlags.or)
    }

    // special handling ph lib
    if (isPh)
    {
      switch (x.name)
      {
        case "Coord":  flags = flags.or(MSpecFlags.haystack)
        case "Symbol": flags = flags.or(MSpecFlags.haystack)
      }
    }

    return flags
  }

  ** If given meta tag defined then set bit flag (or clear if None)
  private Int setMetaFlag(Int flags, ASpec x, Str name, Int bit)
  {
    val := x.ast.meta.get(name)
    if (val == null) return flags
    if (val.isNone)  return flags.and(bit.not)
    return flags.or(bit)
  }

  ** Treat `sys` itself special using names
  private Int computeFlagsSys(ASpec x)
  {
    // maybe
    flags := 0
    if (x.metaHas("maybe")) flags = flags.or(MSpecFlags.maybe)

    // inherited flags
    for (ASpec? p := x; p != null; p = p.base)
    {
      switch (p.name)
      {
        case "Choice":    flags = flags.or(MSpecFlags.choice)
        case "Dict":      flags = flags.or(MSpecFlags.dict)
        case "Entity":    flags = flags.or(MSpecFlags.entity)
        case "File":      flags = flags.or(MSpecFlags.file)
        case "Func":      flags = flags.or(MSpecFlags.func)
        case "Grid":      flags = flags.or(MSpecFlags.grid)
        case "Interface": flags = flags.or(MSpecFlags.interface)
        case "List":      flags = flags.or(MSpecFlags.list)
        case "Marker":    flags = flags.or(MSpecFlags.marker)
        case "MultiRef":  flags = flags.or(MSpecFlags.multiRef)
        case "NA":        flags = flags.or(MSpecFlags.haystack)
        case "None":      flags = flags.or(MSpecFlags.none).or(MSpecFlags.haystack)
        case "Query":     flags = flags.or(MSpecFlags.query)
        case "Ref":       flags = flags.or(MSpecFlags.ref)
        case "Scalar":    flags = flags.or(MSpecFlags.scalar)
        case "This":      flags = flags.or(MSpecFlags.self)
      }
    }

    // haystack Kind specs (non-inherited)
    if (x.isType)
    {
      typeName := x.name
      kind := Kind.fromStr(typeName, false)
      if (kind != null && (typeName != "Obj" && typeName != "Span"))
        flags = flags.or(MSpecFlags.haystack)
    }

    return flags
  }

  ** Handle flags in `sys.comp`
  private Int computeFlagsSysComp(ASpec x)
  {
    if (x.name == "Comp") return MSpecFlags.comp
    return computeFlagsNonSys(x)
  }

}

