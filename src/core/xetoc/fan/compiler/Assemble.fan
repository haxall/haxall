//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Feb 2023  Brian Frank  Creation
//

using util
using xeto
using xetom

**
** Assemble AST into implementation instances
**
@Js
internal class Assemble : Step
{
  override Void run()
  {
    asmLib(lib)
  }

  private Void asmLib(ALib x)
  {
    m := MLib(x.loc, x.name, x.meta.asm, x.flags, x.version, compiler.depends.list, asmTops(x), asmInstances(x), x.files)
    XetoLib#m->setConst(x.asm, m)
    lib.tops.each |spec| { asmTop(spec) }
  }

  private Str:Spec asmTops(ALib x)
  {
    if (x.tops.isEmpty) return noSpecs
    acc := Str:Spec[:]
    x.tops.each |t, n| { acc.add(n, t.asm) }
    return acc
  }

  private Str:Dict asmInstances(ALib x)
  {
    if (x.instances.isEmpty) return noDicts
    acc := Str:Dict[:]
    x.instances.each |d, n| { acc.add(n, d.asm) }
    return acc
  }

  private Void asmTop(ASpec x)
  {
    init := toInit(x)
    MSpec? m
    switch (x.flavor)
    {
      case SpecFlavor.type:
        //m = MType    (x.loc, x.lib.asm, x.qname, x.name, x.base?.asm, x.asm, x.cmeta, x.metaOwn, asmSlots(x), asmSlotsOwn(x), x.flags, x.args, x.binding)
        m = MType(init)
      case SpecFlavor.func:
        //m = MTopFunc (x.loc, x.lib.asm, x.qname, x.name, x.base?.asm, x.ctype.asm, x.cmeta, x.metaOwn, asmSlots(x), asmSlotsOwn(x), x.flags, x.args)
        m = MTopFunc(init)
      case SpecFlavor.global:
        //m = MGlobal  (x.loc, x.lib.asm, x.qname, x.name, x.base?.asm, x.ctype.asm, x.cmeta, x.metaOwn, asmSlots(x), asmSlotsOwn(x), x.flags, x.args)
        //m = MGlobal(init)
        err("Old style globals not supported: $x.name", x.loc)
        return
      case SpecFlavor.mixIn:
        //m = MMixin   (x.loc, x.lib.asm, x.qname, x.name, x.base?.asm, x.ctype.asm, x.cmeta, x.metaOwn, asmSlots(x), asmSlotsOwn(x), x.flags, x.args)
        m = MMixin(init)
      case SpecFlavor.meta:
        //m = MMetaSpec(x.loc, x.lib.asm, x.qname, x.name, x.base?.asm, x.ctype.asm, x.cmeta, x.metaOwn, asmSlots(x), asmSlotsOwn(x), x.flags, x.args)
        m = MMetaSpec(init)
      default:
        throw Err(x.flavor.name)
    }
    mField->setConst(x.asm, m)
    asmChildren(x)
  }

  private Void asmSpec(ASpec x)
  {
    init := toInit(x)
    m := MSpec(init)
    mField->setConst(x.asm, m)
    asmChildren(x)
  }

  private Void asmChildren(ASpec x)
  {
    if (x.slots == null) return
    x.slots.each |kid| { asmSpec(kid) }
  }

  private MSpecMap asmSlotsOwn(ASpec x, Bool isGlobal)
  {
    if (x.slots == null || x.slots.isEmpty) return MSpecMap.empty
    map := Str:XetoSpec[:]
    map.ordered = true
    x.slots.each |kid, name|
    {
      if (kid.isGlobal == isGlobal) map.add(name, kid.asm)
    }
    return MSpecMap(map)
  }

  private MSpecMap asmSlots(ASpec x)
  {
    if (x.cslotsRef.isEmpty) return MSpecMap.empty
    map := Str:XetoSpec[:]
    map.ordered = true
    x.cmembers |s, n|
    {
      if (!s.isGlobal) map[n] = s.asm
    }
    return MSpecMap(map)
  }

  private MSpecInit toInit(ASpec x)
  {
    return MSpecInit
    {
      it.loc        = x.loc
      it.lib        = x.lib.asm
      it.parent     = x.parent?.asm
      it.qname      = x.qname
      it.name       = x.name
      it.base       = x.base?.asm
      it.type       = x.isType ? x.asm : x.ctype.asm
      it.meta       = x.cmeta
      it.metaOwn    = x.metaOwn
      it.slots      = asmSlots(x)
      it.slotsOwn   = asmSlotsOwn(x, false)
      it.globalsOwn = asmSlotsOwn(x, true)
      it.flags      = x.flags
      it.args       = x.args
      it.binding    = x.isType ? x.binding : null
    }
  }

  static const Str:Spec noSpecs := [:]
  static const Str:Dict noDicts := [:]

  Field mField  := XetoSpec#m
}

