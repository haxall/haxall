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
    m := MLib(x.loc, x.name, x.meta, x.flags, x.version, compiler.depends.list, asmTops(x), asmInstances(x), x.files)
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
    if (x.ast.instances.isEmpty) return noDicts
    acc := Str:Dict[:]
    x.ast.instances.each |d, n| { acc.add(n, d.asm) }
    return acc
  }

  private Void asmTop(ASpec x)
  {
    init := toInit(x)
    MSpec? m
    switch (x.flavor)
    {
      case SpecFlavor.type:   m = MType(init)
      case SpecFlavor.func:   m = MTopFunc(init)
      case SpecFlavor.mixIn:  m = MMixin(init)
      case SpecFlavor.global: err("Old style globals not supported: $x.name", x.loc); return
// TODO - move to parser
//      case SpecFlavor.meta:   err("Old style meta not supported: $x.name", x.loc); return
      default:                throw Err(x.flavor.name)
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
    if (x.declared == null) return
    x.declared.each |kid| { asmSpec(kid) }
  }

  private SpecMap asmMembersOwn(ASpec x, Bool isGlobal)
  {
    if (x.declared == null || x.declared.isEmpty) return SpecMap.empty
    map := Str:XetoSpec[:]
    map.ordered = true
    x.declared.each |kid, name|
    {
      if (kid.isGlobal == isGlobal) map.add(name, kid.asm)
    }
    return SpecMap(map)
  }

  private SpecMap asmSlots(ASpec x)
  {
    if (x.members.isEmpty) return SpecMap.empty
    map := Str:XetoSpec[:]
    map.ordered = true
// TODO: duplicates in ASpec
    x.members.each |s, n|
    {
      if (!s.isGlobal) map[n] = s.asm
    }
    return SpecMap(map)
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
      it.type       = x.isType ? x.asm : x.type.asm
      it.meta       = x.meta
      it.metaOwn    = x.metaOwn
      it.slots      = asmSlots(x)
      it.slotsOwn   = asmMembersOwn(x, false)
      it.globalsOwn = x.isType ? asmMembersOwn(x, true) : null
      it.flags      = x.flags
      it.args       = x.args
      it.binding    = x.isType ? x.binding : null
    }
  }

  static const Str:Spec noSpecs := [:]
  static const Str:Dict noDicts := [:]

  Field mField  := XetoSpec#m
}

