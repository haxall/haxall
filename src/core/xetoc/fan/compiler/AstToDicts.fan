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
    acc.ordered = true
    acc["name"] = x.name
    acc["base"] = mapTypeRef(x.typeRef, ns.sys.dict.id)
    acc["spec"] = ns.sys.spec.id
    mapMeta(acc, x.meta)
    acc.addNotNull("slots", mapSlots(x))
    return Etc.dictFromMap(acc)
  }

  Dict? mapSlots(ASpec x)
  {
    if (x.slots == null || x.slots.isEmpty) return null
    acc := Str:Dict[:]
    acc.ordered = true
    x.slots.each |s, n| { acc[n] = mapSlot(s) }
    return Etc.dictFromMap(acc)
  }

  Dict mapSlot(ASpec x)
  {
    acc := Str:Obj[:]
    acc.ordered = true
    acc["type"] = mapTypeRef(x.typeRef, ns.sys.obj.id)
    mapMeta(acc, x.meta)
    acc.addNotNull("slots", mapSlots(x))
    return Etc.dictFromMap(acc)
  }

  Void mapMeta(Str:Obj acc, ADict? meta)
  {
    if (meta == null) return
    meta.each |v, n|
    {
      if (acc[n] == null) acc[n] = mapData(v)
    }
  }

  Dict mapInstance(AInstance x)
  {
    acc := Str:Obj[:]
    acc.ordered = true
    acc["name"] = x.name.toStr
    return mapDict(x, acc)
  }

  Obj mapData(AData x)
  {
    if (x.isAsm) return x.asm
    switch (x.nodeType)
    {
      case ANodeType.scalar: return mapScalar(x)
      default:               throw Err(data.nodeType.name)
    }
  }

  Obj mapScalar(AScalar x)
  {
    // map core xeto types to haystack types, otherwise use string
    str := x.str
    qname := x.typeRefIsResolved ? x.typeRef.deref.qname : null
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
      err("Cannot parse $qname: $str", x.loc)
    }
    return x.str
  }

  Dict mapDict(ADict x, [Str:Obj]? acc)
  {
    if (acc == null)
    {
      acc = Str:Obj[:]
      acc.ordered = true
    }

    if (x.typeRef != null) acc["spec"] = mapTypeRef(x.typeRef)

    x.each |v, n|
    {
      if (acc[n] == null) acc[n] = mapData(v)
    }
    return Etc.dictFromMap(acc)
  }

  Ref mapTypeRef(ASpecRef? x, Ref? def := null)
  {
    if (x == null) return def ?: throw Err("typeRef null")
    if (x.isResolved) return x.deref.id
    return Ref(x.toStr)
  }
}

