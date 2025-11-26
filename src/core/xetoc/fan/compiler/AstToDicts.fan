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
    rtInclude = compiler.opts.has("rtInclude")
    unknownLibPrefix = compiler.libName + "::"

    acc :=  Dict[,]
    lib.tops.each |x| { acc.add(mapSpec(x)) }
    lib.ast.instances.each |x| { acc.add(mapInstance(x)) }
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
    if (rtInclude) acc["rt"] = rtForSpec(x.typeRef)
    mapMeta(acc, x.ast.meta)
    acc.addNotNull("slots", mapSlots(x))
    return Etc.dictFromMap(acc)
  }

  Str rtForSpec(ASpecRef base)
  {
    // Note: this is just a attempt to infer rt as "func", it won't
    // work for other Func subtypes; so callers should ensure proper
    // rt tag if they know the something is a function vs a spec
    n := base.name.name
    isFunc := n == "Func" || n == "Template"
    return isFunc ? "func" : "spec"
  }

  Grid? mapSlots(ASpec x)
  {
    if (x.declared == null || x.declared.isEmpty) return null

    acc := [Str:Obj][,]
    x.declared.each |s, n| { acc.add(mapSlot(s)) }

    cols := Str:Str[:]
    cols.ordered = true
    acc.each |row|
    {
      row.each |v, n| { if (cols[n] == null) cols[n] = n }
    }
    colNames := cols.keys

    gb := GridBuilder()
    colNames.each |n| { gb.addCol(n) }
    acc.each |row|
    {
      cells := Obj?[,]
      cells.capacity = colNames.size
      colNames.each |n| { cells.add(row[n]) }
      gb.addRow(cells)
    }
    return gb.toGrid
  }

  Str:Obj mapSlot(ASpec x)
  {
    acc := Str:Obj[:]
    acc.ordered = true
    acc["name"] = x.name
    acc.addNotNull("type", mapTypeRef(x.typeRef, null))
    mapMeta(acc, x.ast.meta)
    acc.addNotNull("slots", mapSlots(x))
    return acc
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
    if (rtInclude) acc["rt"] = "instance"
    acc["name"] = x.name.toStr
    return mapDict(x, acc)
  }

  Obj mapData(AData x)
  {
    switch (x.nodeType)
    {
      case ANodeType.scalar:  return mapScalar(x)
      case ANodeType.dict:    return mapDict(x, null)
      case ANodeType.dataRef: return mapRef(x)
      case ANodeType.specRef: return mapRef(x)
      default:                throw Err(data.nodeType.name)
    }
  }

  Obj mapScalar(AScalar x)
  {
    if (x.isAsm) return x.asm

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

  Obj mapDict(ADict x, [Str:Obj]? acc)
  {
    if (x.isList && acc == null) return mapList(x)

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

  Obj?[] mapList(ADict x)
  {
    acc := Obj?[,]
    x.each |v| { acc.add(mapData(v)) }
    return acc
  }

  Obj mapRef(ARef x)
  {
    Ref(x.toStr)
  }

  Ref? mapTypeRef(ASpecRef? x, Ref? def := null)
  {
    if (x == null) return def
    if (x.isResolved) return x.deref.id

    // always return qname even if it not resolved;
    // use libName from options if we need to make it a qname
    str := x.toStr
    if (!str.contains("::")) str = unknownLibPrefix + str
    return Ref(str)
  }

  Bool rtInclude
  Str? unknownLibPrefix
}

