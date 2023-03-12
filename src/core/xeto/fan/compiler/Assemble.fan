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
      case ANodeType.ref:    return asmRef(x)
      case ANodeType.val:    return asmVal(x)
      case ANodeType.spec:   return asmSpec(x)
      case ANodeType.type:   return asmType(x)
      case ANodeType.lib:    return asmLib(x)
      default: throw Err(x.nodeType.toStr)
    }
  }

  private Void asmRef(ARef x)
  {
    x.asm
  }

  private Void asmVal(AVal x)
  {
    // check if already assembled
    if (x.asmRef != null) return

    switch (x.valType)
    {
      case AValType.scalar:  x.asmRef = asmScalar(x)
      case AValType.typeRef: x.asmRef = asmTypeRef(x)
      case AValType.list:    x.asmRef = asmList(x)
      case AValType.dict:    x.asmRef = asmDict(x)
      default: throw Err(x.valType.name)
    }
  }

  private Obj? asmScalar(AObj x)
  {
    // if value is null or already assembled
    v := x.val
    if (v == null) return null
    if (v.isAsm) return v.asm

    // sanity check
    if (x.type == null) err("asmScalar without type", x.loc)

    // map to Fantom type to parse
    qname := x.valParseType
    item := env.factory.fromXeto[qname]
    if (item != null)
    {
      // parse to Fantom type
      return v.val = item.parse(compiler, v.str, v.loc)
    }
    else
    {
      // just fallback to a string value
      return v.val = v.str
    }
  }

  private XetoType asmTypeRef(AVal x)
  {
    if (x.type == null) throw err("wtf-1", x.loc)
    if (x.meta != null) throw err("wtf-2", x.loc)
    return x.type.asm
  }

  private Obj?[] asmList(AVal x)
  {
    list := List(x.asmToListOf, x.slots.size)
    x.slots.each |obj| { list.add(obj.asm) }
    return list
  }

  private DataDict asmDict(AVal x)
  {
    // spec
    DataSpec? spec := null
    if (x.type != null)
    {
      if (x.meta != null)
        err("Dict type with meta not supported", x.loc)
      else
        spec = x.type.asm
    }

    // name/value pairs
    acc := Str:Obj[:]
    acc.ordered = true
    x.slots.each |obj, name| { acc[name] = obj.asm }

    return env.dictMap(acc, spec)
  }

  private Void asmLib(ALib x)
  {
    m := MLib(env, x.loc, x.qname, x.type.asm, asmMeta(x), asmSlots(x))
    mField->setConst(x.asm, m)
    mlField->setConst(x.asm, m)
  }

  private Void asmType(AType x)
  {
    m := MType(x.loc, x.lib.asm, x.qname, x.name, x.base?.asm, x.asm, asmMeta(x), asmSlots(x), x.flags)
    mField->setConst(x.asm, m)
  }

  private Void asmSpec(ASpec x)
  {
    m := MSpec(x.loc, x.parent.asm, x.name, x.base.asm, x.type.asm, asmMeta(x), asmSlots(x), x.flags)
    mField->setConst(x.asm, m)
  }

  private DataDict asmMeta(ASpec x)
  {
    if (x.meta == null && x.val == null) return env.dict0

    DataDict dict := x.meta == null ? env.dict0 : asmDict(x.meta)

    // TODO: just temp hack for now
    if (x.val != null)
    {
      acc := Str:Obj[:]
      dict.each |v, n| { acc[n] = v }
      acc.add("val", asmScalar(x))
      dict = env.dictMap(acc)
    }

    return dict
  }

  private MSlots asmSlots(ASpec x)
  {
    if (x.slots == null || x.slots.isEmpty) return MSlots.empty
    acc := Str:XetoSpec[:]
    acc.ordered = true
    x.slots.each |kid, name| { acc.add(name, kid.asm) }
    return MSlots(acc)
  }

  Field mField  := XetoSpec#m
  Field mlField := XetoLib#ml
}