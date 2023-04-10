//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Apr 2023  Brian Frank  Creation
//

using util
using data

**
** Reify creates concrete Fantom object for all the AVal objects
** in the abstract syntax tree as their assembly value.
**
@Js
internal class Reify : Step
{
  override Void run()
  {
    ast.walk |x|
    {
      if (x.nodeType === ANodeType.val) asm(x)
      if (x is ASpec) asmSpecVal(x)
    }
  }

  private Void asmSpecVal(ASpec x)
  {
    DataDict own := x.meta?.asm ?: env.dict0
    if (x.val != null)
    {
      val := asmScalar(x)

      // TODO - not efficient
      if (own.isEmpty)
      {
        own = env.dict1("val", val)
      }
      else
      {
        acc := Str:Obj[:]
        acc.ordered = true
        own.each |v, n| { acc[n] = v }
        acc["val"] = val
        own = env.dictMap(acc)
      }
    }
    x.metaOwnRef = own
  }

  private Void asm(AVal x)
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
}