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
    bombIfErr
    compiler.dicts = acc
  }

  Dict mapSpec(ASpec x)
  {
    acc := Str:Obj[:]
    if (x.meta != null)
    {
      x.meta.each |v, n|
      {
        acc[n] = mapData(v)
      }
    }
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

  Obj mapData(AData data)
  {
    if (data.isAsm) return data.asm
    switch (data.nodeType)
    {
      case ANodeType.scalar: return mapScalar(data)
      default:               throw Err(data.nodeType.name)
    }
  }

  Obj mapScalar(AScalar data)
  {
    // map core xeto types to haystack types, otherwise use string
    str := data.str
    qname := data.typeRefIsResolved ? data.typeRef.deref.qname : null
    if (qname != null && qname.startsWith("sys::"))
    {
      Obj? val := null
      switch (qname)
      {
        case "sys::Date":     val = Date(str, false)
        case "sys::DateTime": val = DateTime(str, false)
        case "sys::Marker":   val = str == "Marker" ? Marker.val : null
        case "sys::Ref":      val = Ref(str, false)
        case "sys::Time":     val = Time(str, false)
        default:              val = str
      }
      if (val != null) return val
      err("Cannot parse $qname: $str", data.loc)
    }
    return data.str
  }

  Ref mapTypeRef(ASpecRef? x, Ref? def := null)
  {
    if (x == null) return def ?: throw Err("typeRef null")
    if (x.isResolved) return x.deref.id
    return Ref(x.toStr)
  }
}

