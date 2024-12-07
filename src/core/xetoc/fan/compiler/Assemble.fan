//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Feb 2023  Brian Frank  Creation
//

using util
using xeto
using xetoEnv

**
** Assemble AST into implementation instances
**
internal class Assemble : Step
{
  override Void run()
  {
    asmLib(lib)
  }

  private Void asmLib(ALib x)
  {
    m := MLib(x.loc, x.nameCode, x.name, x.meta.asm, x.flags, x.version, compiler.depends.list, asmTops(x), asmInstances(x), x.files)
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
    MSpec? m
    switch (x.flavor)
    {
      case SpecFlavor.type:
        m = MType(x.loc, x.lib.asm, x.qname, x.nameCode, x.name, x.base?.asm, x.asm, x.cmeta, x.metaOwn, asmSlots(x), asmSlotsOwn(x), x.flags, x.args, x.binding)
      case SpecFlavor.global:
        m = MGlobal(x.loc, x.lib.asm, x.qname, x.nameCode, x.name, x.base?.asm, x.ctype.asm, x.cmeta, x.metaOwn, asmSlots(x), asmSlotsOwn(x), x.flags, x.args)
      case SpecFlavor.meta:
        m = MMetaSpec(x.loc, x.lib.asm, x.qname, x.nameCode, x.name, x.base?.asm, x.ctype.asm, x.cmeta, x.metaOwn, asmSlots(x), asmSlotsOwn(x), x.flags, x.args)
      default:
        throw Err(x.flavor.name)
    }
    mField->setConst(x.asm, m)
    asmChildren(x)
  }

  private Void asmSpec(ASpec x)
  {
    m := MSpec(x.loc, x.parent.asm, x.nameCode, x.name, x.base.asm, x.ctype.asm, x.cmeta, x.metaOwn, asmSlots(x), asmSlotsOwn(x), x.flags, x.args)
    mField->setConst(x.asm, m)
    asmChildren(x)
  }

  private Void asmChildren(ASpec x)
  {
    if (x.slots == null) return
    x.slots.each |kid| { asmSpec(kid) }
  }

  private MSlots asmSlotsOwn(ASpec x)
  {
    if (x.slots == null || x.slots.isEmpty) return MSlots.empty
    map := Str:XetoSpec[:]
    map.ordered = true
    x.slots.each |kid, name| { map.add(name, kid.asm) }
    dict := names.dictMap(map)
    return MSlots(dict)
  }

  private MSlots asmSlots(ASpec x)
  {
    if (x.cslotsRef.isEmpty) return MSlots.empty
    map := Str:XetoSpec[:]
    map.ordered = true
    x.cslots |s, n| { map[n] = s.asm }
    dict := names.dictMap(map)
    return MSlots(dict)
  }

  static const Str:Spec noSpecs := [:]
  static const Str:Dict noDicts := [:]

  Field mField  := XetoSpec#m
}

