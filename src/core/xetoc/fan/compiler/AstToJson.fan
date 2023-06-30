//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Apr 2023  Brian Frank  Creation
//

using util
using xeto

**
** Convert AST to JSON
**
@Js
internal class AstToJson : Step
{
  override Void run()
  {
    // for right now we just use this for parsePragma
    ast := pragma?.meta ?: throw err("No pragma meta", FileLoc(compiler.input))
    compiler.json = genDict(ast)
  }

  private Dict genDict(AVal obj)
  {
    acc := Str:Obj[:]
    obj.slots.each |v|
    {
      acc[v.name] = genVal(v)
    }
    return env.dict(acc)
  }

  private Obj[] genList(AVal obj)
  {
    acc := Obj[,]
    obj.slots.each |v|
    {
      acc.add(genVal(v))
    }
    return acc
  }

  private Obj genVal(AVal obj)
  {
    if (obj.name == "depends") return genList(obj)
    switch (obj.valType)
    {
      case AValType.scalar:  return obj.val.str
      case AValType.typeRef: return obj.typeRef.toStr
      case AValType.list:    return genList(obj)
      case AValType.dict:    return genDict(obj)
      default: throw err("AstToJson: $obj.valType", obj.loc)
    }
  }
}