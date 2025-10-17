//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Oct 2025  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** Encode AST into a list of dicts
**
@Js
internal class AstToDicts : Step
{
  override Void run()
  {
    acc :=  Dict[,]
    lib.tops.each |x| { acc.add(mapSpec(x)) }
    lib.instances.each |x| { acc.add(mapInstance(x)) }
    compiler.dicts = acc
  }

  Dict mapSpec(ASpec x)
  {
    acc := Str:Obj[:]
    acc["name"] = x.name
    acc["base"] = mapTypeRef(x.typeRef, ns.sys.dict.id)
    acc["spec"] = ns.sys.spec.id
    return Etc.dictFromMap(acc)
  }

  Dict mapInstance(AInstance x)
  {
    acc := Str:Obj[:]
    acc["name"] = x.name
    return Etc.dictFromMap(acc)
  }

  Ref mapTypeRef(ASpecRef? x, Ref? def := null)
  {
    if (x == null) return def ?: throw Err("typeRef null")
    if (x.isResolved) return x.deref.id
    return Ref(x.toStr)
  }
}

