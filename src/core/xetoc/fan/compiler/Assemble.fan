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
    m := MLib(env, x.loc, x.name, x.meta.asm, x.version, compiler.depends, asmTypes(x), asmInstances(x))
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
    m := MType(x.loc, x.lib.asm, x.qname, x.name, x.base?.asm, x.asm, x.cmeta, x.metaOwn, asmSlots(x), asmSlotsOwn(x), x.flags, x.factory)
    mField->setConst(x.asm, m)
    asmChildren(x)
  }

  private Void asmSpec(ASpec x)
  {
    m := MSpec(x.loc, x.parent.asm, x.name, x.base.asm, x.type.asm, x.cmeta, x.metaOwn, asmSlots(x), asmSlotsOwn(x), x.flags)
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
    acc := Str:XetoSpec[:]
    acc.ordered = true
    x.slots.each |kid, name| { acc.add(name, kid.asm) }
    return MSlots(acc)
  }

  private MSlots asmSlots(ASpec x)
  {
    if (x.cslots.isEmpty) return MSlots.empty
    return MSlots(x.cslots.map |s->XetoSpec| { s.asm })
  }

  static const Str:Spec noSpecs := [:]
  static const Str:Dict noDicts := [:]

  Field mField  := XetoSpec#m
}