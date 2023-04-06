//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Dec 2022  Brian Frank  Creation
//    3 Mar 2023  Brian Frank  Redesign from proto
//

using util

**
** Infer unspecified types from inherited specs
**
@Js
internal class Infer : Step
{
  override Void run()
  {
    ast.walk |x|
    {
      obj := x as AObj
      if (obj != null)
      {
        inferObj(obj)
        if (obj.isSpec) computeFlags(obj)
      }
    }
    bombIfErr
  }

//////////////////////////////////////////////////////////////////////////
// Infer
//////////////////////////////////////////////////////////////////////////

  private Void inferObj(AObj x)
  {
    // short circuit if type already specified
    if (x.type != null) return

    // types without a supertype are assumed to be sys::Dict
    if (x.isType)
    {
      t := (AType)x
      if (t.qname == "sys::Obj") return
      t.type = sys.dict
      return
    }

    // TODO: total hack until we get inheritance
    if (x.name == "points")
    {
      x.type = sys.query
      return
    }

    // TODO: fallback to Str/Dict
    if (x.val != null)
      x.type = sys.str
    else
      x.type = sys.dict
  }

//////////////////////////////////////////////////////////////////////////
// Flags
//////////////////////////////////////////////////////////////////////////

  ** Compute flags for system types x directly inherits
  private Void computeFlags(ASpec x)
  {
    x.flags = isSys ? computeFlagsSys(x) : computeFlagsNonSys(x)
  }

  private Int computeFlagsNonSys(ASpec x)
  {
    // walk inheritance tree until we get to an external
    // type from a dependency and get inherited flags
    p := x
    while (p.base.isResolvedInternal)
    {
      p = p.base.resolvedInternal
      if (x === p) { err("Cyclic inheritance: $x.name", x.loc); return 0 }
    }
    flags := p.base.asm.m.flags

    // merge in my own flags
    if (x.metaHas("maybe")) flags = flags.or(MSpecFlags.maybe)

    return flags
  }

  ** We have to treat 'sys' itself special using names
  private Int computeFlagsSys(ASpec x)
  {
    flags := 0
    if (x.metaHas("maybe")) flags = flags.or(MSpecFlags.maybe)
    for (ASpec? p := x; p != null; p = p.base?.resolvedInternal)
    {
      switch (p.name)
      {
        case "Marker": flags = flags.or(MSpecFlags.marker)
        case "Scalar": flags = flags.or(MSpecFlags.scalar)
        case "Seq":    flags = flags.or(MSpecFlags.seq)
        case "Dict":   flags = flags.or(MSpecFlags.dict)
        case "List":   flags = flags.or(MSpecFlags.list)
        case "Query":  flags = flags.or(MSpecFlags.query)
      }
    }
    return flags
  }

}