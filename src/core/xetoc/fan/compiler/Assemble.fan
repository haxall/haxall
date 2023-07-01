//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Feb 2023  Brian Frank  Creation
//

using util
using xeto

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
    m := MLib(env, x.loc, x.qname, x.type.asm, x.metaOwn, asmSlotsOwn(x), x.version, compiler.depends)
    mField->setConst(x.asm, m)
    mlField->setConst(x.asm, m)
    asmChildren(x)
  }

  private Void asmType(AType x)
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
    x.slots.each |kid|
    {
      if (kid.isType)
        asmType(kid)
      else
        asmSpec(kid)
    }
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

  Field mField  := XetoSpec#m
  Field mlField := XetoLib#ml
}