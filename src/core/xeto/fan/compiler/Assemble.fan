//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Feb 2023  Brian Frank  Creation
//

using util
using data

**
** Assemble AST into implementation instances
**
@Js
internal class Assemble : Step
{
  override Void run()
  {
    ast.walk |x| { asmNode(x) }
  }

  private Void asmNode(ANode x)
  {
    switch (x.nodeType)
    {
      case ANodeType.spec:   return asmSpec(x)
      case ANodeType.type:   return asmType(x)
      case ANodeType.lib:    return asmLib(x)
    }
  }

  private Void asmLib(ALib x)
  {
    m := MLib(env, x.loc, x.qname, x.type.asm, asmMeta(x), asmSlotsOwn(x))
    mField->setConst(x.asm, m)
    mlField->setConst(x.asm, m)
  }

  private Void asmType(AType x)
  {
    m := MType(x.loc, x.lib.asm, x.qname, x.name, x.base?.asm, x.asm, asmMeta(x), asmSlotsOwn(x), asmSlots(x), x.flags)
    mField->setConst(x.asm, m)
  }

  private Void asmSpec(ASpec x)
  {
    m := MSpec(x.loc, x.parent.asm, x.name, x.base.asm, x.type.asm, asmMeta(x), asmSlotsOwn(x), asmSlots(x), x.flags)
    mField->setConst(x.asm, m)
  }

  private DataDict asmMeta(ASpec x)
  {
    if (x.meta == null && x.val == null) return env.dict0

    acc := Str:Obj[:]
    acc.ordered = true
    if (x.meta != null) x.meta.slots.each |obj, name| { acc[name] = obj.asm }
    if (x.val != null) acc["val"] = x.val.asm
    return env.dictMap(acc)
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