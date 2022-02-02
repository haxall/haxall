//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 May 2012  Brian Frank  Creation
//

using haystack
using [java] fanx.interop
using [java] sedona::Constants
using [java] sedona::Value
using [java] sedona::Type   as SedonaType
using [java] sedona::Slot   as SedonaSlot
using [java] sedona::Bool   as SedonaBool
using [java] sedona::Byte   as SedonaByte
using [java] sedona::Short  as SedonaShort
using [java] sedona::Int    as SedonaInt
using [java] sedona::Long   as SedonaLong
using [java] sedona::Float  as SedonaFloat
using [java] sedona::Double as SedonaDouble
using [java] sedona::Str    as SedonaStr
using [java] sedona::Buf    as SedonaBuf
using [java] sedona.sox

**
** Sedona utilities
**
class SedonaUtil
{
  static Dict compToDict(SoxComponent comp)
  {
    tags := Str:Obj?[:] { ordered = true }
    SedonaSlot[] props := comp.type.props
    tags["dis"] = comp.name
    tags["compId"] = Number.makeInt(comp.id)
    tags["parentId"] = Number.makeInt(comp.parentId)
    tags["path"] = comp.path
    tags["type"] = comp.type.qname
    tags["meta"] = "0x"+comp.getInt("meta").toHex
    tags["childrenIds"] = idsToStr(comp.childrenIds)
    props.each |slot|
    {
      name := slot.name
      if (name == "meta") return
      if (tags.containsKey(name)) name = "${name}_prop"
      tags[name] = valueToFan(comp.get(slot))
    }
    return Etc.makeDict(tags)
  }

  static Obj? valueToFan(Value? v, Unit? unit := null)
  {
    if (v == null || v.isNull) return null
    switch (v.typeId)
    {
      case Constants.voidId:   return null
      case Constants.boolId:   return ((SedonaBool)v).val
      case Constants.byteId:   return Number.makeInt(((SedonaByte)v).val, unit)
      case Constants.shortId:  return Number.makeInt(((SedonaShort)v).val, unit)
      case Constants.intId:    return Number.makeInt(((SedonaInt)v).val, unit)
      case Constants.longId:   return Number.makeInt(((SedonaLong)v).val, unit)
      case Constants.floatId:  return Number.make(((SedonaFloat)v).val, unit)
      case Constants.doubleId: return Number.make(((SedonaDouble)v).val, unit)
      case Constants.bufId:    return ((SedonaBuf)v).dumpToString
      case Constants.strId:    return ((SedonaStr)v).val
      default:
        echo("Unknown sedona value type $v.typeId")
        return null
    }
  }

  static Value fanToValue(SedonaType type,  Obj? v)
  {
    num := v as Number
    int := num == null ? 0 : num.toInt

    switch (type.id)
    {
      case Constants.boolId:   return v == null ? SedonaBool.NULL : SedonaBool.make((Bool)v)

      case Constants.byteId:   return SedonaByte.make(int)
      case Constants.shortId:  return SedonaShort.make(int)
      case Constants.intId:    return SedonaInt.make(int)
      case Constants.longId:   return SedonaLong.make(int)

      case Constants.floatId:   return v == null ? SedonaFloat.NULL   : SedonaFloat.make(num.toFloat)
      case Constants.doubleId:  return v == null ? SedonaDouble.NULL : SedonaDouble.make(num.toFloat)

      case Constants.strId:     return SedonaStr.make((Str)v)

      default: throw Err("Cannot map $v to $type")
    }

  }

  static Str? sedonaTypeToKind(SedonaType type)
  {
    if (type.isInteger ||
        type.id == SedonaType.longId ||
        type.id == SedonaType.floatId ||
        type.id == SedonaType.doubleId) return "Number"

    if (type.id == SedonaType.boolId) return "Bool"

    return null
  }

  static Str idsToStr(IntArray array)
  {
    s := StrBuf()
    s.capacity = array.size * 3
    for (i:=0; i<array.size; ++i) s.join(array[i], ",")
    return s.toStr
  }
}