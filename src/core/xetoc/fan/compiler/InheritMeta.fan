//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Apr 2023  Brian Frank  Creation
//

using util
using xeto
using xetoEnv
using haystack

**
** InheritMeta computes the effective meta for all the specs
**
internal class InheritMeta : Step
{
  override Void run()
  {
    if (isData) return
    lib.tops.each |spec| { inherit(spec) }
    bombIfErr
  }

  private Void inherit(ASpec spec)
  {
    // if already processed skip
    if (spec.cmetaRef != null) return

    // process this spec
    spec.cmetaRef = computeMeta(spec)

    // compute arguments
    spec.argsRef = computeArgs(spec)

    // recurse children slots
    if (spec.slots != null) spec.slots.each |slot| { inherit(slot) }
  }

  private Dict computeMeta(ASpec spec)
  {
    own := spec.metaOwn

    // if base is null this is sys::Obj; otherwise recursively process base
    base := spec.base
    if (spec.base == null) return own
    if (base.isAst) inherit(base)

    // walk thru base tags and map tags we inherit
    acc := Str:Obj[:]
    acc.ordered = true
    baseSize := computedInherited(acc, spec, base)

    // if we inherited all of the base tags and
    // I have none of my own, then reuse base meta
    if (acc.size == baseSize && own.isEmpty && spec.val == null)
      return base.cmeta

    // merge in my own tags
    XetoUtil.addOwnMeta(acc, own)

    // special handling for None val (which gets treated as meta remove)
    if (isSys && spec.name == "None")
      acc["val"] = Remove.val

    return MNameDict(names.dictMap(acc))
  }

  private Int computedInherited(Str:Obj acc, ASpec spec, CSpec base)
  {
    if (spec.isAnd) return computeUnion(acc, spec.cofs, spec.loc)
    if (spec.isOr)  return computeIntersection(acc, spec.cofs)
    return computeFromBase(acc, base, spec.loc)
  }

  private Int computeFromBase(Str:Obj acc, CSpec base, FileLoc loc)
  {
    baseSize := 0
    base.cmeta.each |v, n|
    {
      baseSize++
      if (isInherited(base, n, loc) && acc[n] == null) acc[n] = v
    }
    return baseSize
  }

  private Bool isInherited(CSpec base, Str name, FileLoc loc)
  {
    if (name == "val") return !base.isEnum

    metaSpec := cns.metaSpec(name, loc)
    if (metaSpec == null) return true

    if (metaSpec.cmetaHas("noInherit")) return false

    return true
  }

  private Int computeUnion(Str:Obj acc, CSpec[]? ofs, FileLoc loc)
  {
    if (ofs == null) return 0
    baseSize := 0
    ofs.each |of|
    {
      if (of.isAst) inherit(of)
      baseSize += computeFromBase(acc, of, loc)
    }
    return baseSize
  }

  private Int computeIntersection(Str:Obj acc, CSpec[]? ofs)
  {
    // do we want to do this for or types?
    return 0
  }

  private MSpecArgs computeArgs(ASpec spec)
  {
    of := spec.metaGet("of")
    if (of != null)
    {
      if (of.nodeType != ANodeType.specRef)
        err("Invalid value for 'of' meta, not a spec", of.loc)
      else
        return MSpecArgsOf(of.asm)
    }

    ofs := spec.metaGet("ofs") as ADict
    if (ofs != null)
    {
      acc := Spec[,]
      acc.capacity = ofs.size
      ofs.each |ASpecRef ref| { acc.add(ref.asm) }
      return MSpecArgsOfs(acc)
    }

    if (spec.base != null) return spec.base.args

    return MSpecArgs.nil
  }

}

