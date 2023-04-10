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
** in the abstract syntax tree as their assembly value.  We use this
** step to finalize the ASpec.metaOwn dict.
**
@Js
internal class Reify : Step
{
  override Void run()
  {
    if (isLib)
      walkSpecs(lib) |x| { asmSpec(x) }
    else
      walkVals(ast) |x| { asmVal(x) }
  }

//////////////////////////////////////////////////////////////////////////
// Specs
//////////////////////////////////////////////////////////////////////////

  private Void asmSpec(ASpec x)
  {
    // assemble default value into meta
    if (x.val != null)
    {
      // assemble as scalar using my own type
      scalarType := x.isType ? x : x.type
      val := asmScalar(x, scalarType)

      // insert into meta
      AVal obj := x.metaInit(sys).makeChild(x.val.loc, "val")
      obj.asmRef = val
      x.meta.slots.add(obj)
    }

    // finalize the spec's metaOwn dict
    if (x.meta != null)
    {
      walkVals(x.meta) |obj| { asmVal(obj) }
      x.metaOwnRef = x.meta.asm
    }
    else
    {
      x.metaOwnRef = env.dict0
    }
  }

//////////////////////////////////////////////////////////////////////////
// Values
//////////////////////////////////////////////////////////////////////////

  private Void asmVal(AVal x)
  {
    // check if already assembled
    if (x.asmRef != null) return

    // infer type
    if (x.typeRef == null)
      x.typeRef = x.val == null ? sys.dict : sys.str

    switch (x.valType)
    {
      case AValType.scalar:  x.asmRef = asmScalar(x, x.type)
      case AValType.typeRef: x.asmRef = asmTypeRef(x)
      case AValType.list:    x.asmRef = asmList(x)
      case AValType.dict:    x.asmRef = asmDict(x)
      default: throw Err(x.valType.name)
    }
  }

  private Obj? asmScalar(AObj x, CSpec scalarType)
  {
    // if value is null or already assembled
    v := x.val
    if (v == null) return null
    if (v.isAsm) return v.asm

    // sanity check
    if (x.type == null) err("asmScalar without type", x.loc)

    // map to Fantom type to parse
    qname := scalarType.qname
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