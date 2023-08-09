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
    nameCode := env.names.add(x.name)
    m := MLib(env, x.loc, nameCode, x.meta.asm, x.version, compiler.depends, asmTypes(x), asmInstances(x))
    XetoLib#m->setConst(x.asm, m)
    lib.specs.each |spec| { asmType(spec) }
  }

  private Str:Spec asmTypes(ALib x)
  {
    if (x.specs.isEmpty) return noSpecs
    acc := Str:Spec[:]
    x.specs.each |t, n| { acc.add(n, t.asm) }
    return acc
  }

  private Str:Dict asmInstances(ALib x)
  {
    if (x.instances.isEmpty) return noDicts
    acc := Str:Dict[:]
    x.instances.each |d, n| { acc.add(n, d.asm) }
    return acc
  }

  private Void asmType(ASpec x)
  {
    m := MType(x.loc, env, x.lib.asm, x.qname, x.nameCode, x.base?.asm, x.asm, x.cmeta, x.metaOwn, asmSlots(x), asmSlotsOwn(x), x.flags, x.factory)
    mField->setConst(x.asm, m)
    asmChildren(x)
  }

  private Void asmSpec(ASpec x)
  {
    nameCode := env.names.add(x.name)
    m := MSpec(x.loc, env, x.parent.asm, nameCode, x.base.asm, x.type.asm, x.cmeta, x.metaOwn, asmSlots(x), asmSlotsOwn(x), x.flags)
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
    dict := env.names.dictMap(map)
    return MSlots(dict)
  }

  private MSlots asmSlots(ASpec x)
  {
    if (x.cslotsRef.isEmpty) return MSlots.empty
    map := Str:XetoSpec[:]
    map.ordered = true
    x.cslots |s, n| { map[n] = s.asm }
    dict := env.names.dictMap(map)
    return MSlots(dict)
  }

  static const Str:Spec noSpecs := [:]
  static const Str:Dict noDicts := [:]

  Field mField  := XetoSpec#m
}