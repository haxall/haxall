//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Apr 2023  Brian Frank  Creation
//

using util
using xeto
using xetom
using haystack

**
** InheritMeta computes the effective meta for all the specs
**
@Js
internal class InheritMeta : Step
{
  override Void run()
  {
    if (isData) return
    specType = isSys ? lib.ast.type("Spec") : ns.sysLib.type("Spec")
    lib.tops.each |spec| { inherit(spec) }
    bombIfErr
  }

  private Void inherit(ASpec spec)
  {
    // if already processed skip
    if (spec.ast.cmeta != null) return

    // process this spec
    spec.ast.cmeta = computeMeta(spec)

    // compute arguments
    spec.ast.args = computeArgs(spec)

    // recurse children slots
    if (spec.declared != null) spec.declared.each |slot| { inherit(slot) }
  }

  private Dict computeMeta(ASpec spec)
  {
    own := spec.metaOwn

    // if base is null this is sys::Obj; otherwise recursively process base
    base := spec.base
    if (base == null) return own
    if (base.isAst) inherit(base)

    // walk thru base tags and map tags we inherit
    acc := Str:Obj[:]
    acc.ordered = true
    baseSize := computedInherited(acc, spec, base)

    // if we inherited all of the base tags and
    // I have none of my own, then reuse base meta
    if (acc.size == baseSize && own.isEmpty && spec.val == null)
      return base.meta

    // merge in my own tags
    XetoUtil.addOwnMeta(acc, own)

    // special handling for None val (which gets treated as meta remove)
    if (isSys && spec.name == "None")
      acc["val"] = Remove.val

    return Etc.dictFromMap(acc)
  }

  private Int computedInherited(Str:Obj acc, ASpec spec, Spec base)
  {
    if (spec.isAnd) return computeUnion(acc, spec.ofs(false), spec.loc)
    if (spec.isOr)  return computeIntersection(acc, spec.ofs(false))
    return computeFromBase(acc, base, spec.loc)
  }

  private Int computeFromBase(Str:Obj acc, Spec base, FileLoc loc)
  {
    baseSize := 0
    base.meta.each |v, n|
    {
      baseSize++
      if (isInherited(base, n, loc) && acc[n] == null) acc[n] = v
    }
    return baseSize
  }

  private Bool isInherited(Spec base, Str name, FileLoc loc)
  {
    if (name == "val") return !base.isEnum

    slot := metas.get(name, false)

    if (slot == null) return true

    if (metaHas(slot, "noInherit")) return false

    return true
  }

  private Int computeUnion(Str:Obj acc, Spec[]? ofs, FileLoc loc)
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

  private Int computeIntersection(Str:Obj acc, Spec[]? ofs)
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

    if (spec.base != null) return specToArgs(spec.base)

    return MSpecArgs.nil
  }

  Spec? specType
}

**************************************************************************
** MixinMeta
**************************************************************************

**
** Compute effective spec slots including mixins and set compiler.metas
**
@Js
internal class MixinMeta : Step
{
  override Void run()
  {
    // if sys use the AST slots
    if (isSys)
    {
      type := lib.ast.type("Spec")
      compiler.metas = SpecMap(type.ast.declared)
      return
    }

    // otherwise start with sys::Spec
    acc := SpecMap[,]
    specType := ns.sys.spec
    acc.add(specType.slots)

    // add in all the dependencies
    depends.libs.each |lib|
    {
      add(acc, lib.mixinFor(specType, false)?.slotsOwn)
    }

    // add in my own mixin
    myMixin := lib.ast.mixIn("Spec")
    if (myMixin != null && myMixin.ast.declared != null)
    {
      acc.add(SpecMap(myMixin.ast.declared))
    }
    compiler.metas = SpecMap(acc)
  }

  private static Void add(SpecMap[] acc, SpecMap? map)
  {
    if (map != null && !map.isEmpty) acc.add(map)
  }
}

