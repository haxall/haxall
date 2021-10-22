//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Oct 2021  Matthew Giannini  Creation
//

class JsonEncoder
{
  static Map encode(Obj? val)
  {
    JsonEncoder().encodeVal(val)
  }

  private new make()
  {
  }

  Obj? encodeVal(Obj? val)
  {
    if (val == null) return null
    if (val is Str)  return val
    if (val is Bool) return val
    if (val is Num)  return val
    if (val is List) return encodeList(val)
    if (val is Map)  return encodeMap(val)
    return encodeObj(val)
  }

  Obj encodeObj(Obj obj)
  {
    // check if obj knows how to turn itself into JSON
    encoder := obj.typeof.method("toJson", false)
    if (encoder != null) return encoder.callOn(obj, null)

    // encode fields of object to JSON map
    json := Str:Obj?[:] { ordered = true }
    obj.typeof.fields.each |field|
    {
      if (!acceptField(field)) return
      val := field.get(obj)
      if (val == null) return
      json[toPropName(field)] = encodeVal(val)
    }
    return json
  }

  List encodeList(List val)
  {
    val.map |item| { encodeVal(item) }
  }

  Map encodeMap(Map val)
  {
    json := Str:Obj?[:] { ordered = true }
    val.each |v, k|
    {
      json[k.toStr] = encodeVal(v)
    }
    return json
  }

  private static Bool acceptField(Field field)
  {
    if (field.hasFacet(JsonIgnore#)) return false
    if (field.isStatic) return false
    // if (field.parent == DockerHttpCmd#) return false
    // if (field.parent == DockerJsonCmd#) return false
    return true
  }

  private static Str toPropName(Field field)
  {
    field.name.capitalize
  }
}