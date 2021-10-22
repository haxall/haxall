//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Oct 2021  Matthew Giannini  Creation
//

using util

class JsonDecoder
{
  new make() { }

  Obj? decodeVal(Obj? json, Type asType)
  {
    if (json == null)        return null
    if (Str# === asType)     return decodeStr(json)
    if (Bool# === asType)    return decodeBool(json)
    if (Int# === asType)     return decodeNum(json).toInt
    if (Float# === asType)   return decodeNum(json).toFloat
    if (asType.fits(List#))  return decodeList(json, asType)
    if (asType.fits(Map#))   return decodeMap(json, asType)
    return decodeObj(json, asType)
  }

  private Str decodeStr(Obj v)
  {
    if (v is Str) return v
    throw valErr(v, Str#)
  }

  private Bool decodeBool(Obj v)
  {
    if (v is Bool) return v
    throw valErr(v, Bool#)
  }

  private Num decodeNum(Obj v)
  {
    if (v is Num) return v
    throw valErr(v, Num#)
  }

  private List decodeList(Obj json, Type listType)
  {
    v := json as List
    if (v == null) throw valErr(json, listType)

    of  := listType.params["V"]
    acc := List.make(of, v.size)
    v.each |item| { acc.add(decodeVal(item, of)) }
    return acc
  }

  private Map decodeMap(Obj json, Type mapType)
  {
    v := json as Map
    if (v == null) throw valErr(json, mapType)

    keyType := mapType.params["K"]
    valType := mapType.params["V"]
    map := Map(mapType)
    v.each |val, key|
    {
      map[decodeVal(key, keyType)] = decodeVal(val, valType)
    }
    return map
  }

  // private Obj decodeObj(Str:Obj? json, Type type)
  private Obj decodeObj(Obj? obj, Type type)
  {
    // check for fromStr
    if (obj is Str)
    {
      return type.method("fromStr").call(obj)
    }

    // decode json
    json := ([Str:Obj?])obj
    // check if type has fromJson() constructor
    fromJson := type.method("fromJson", false)
    if (fromJson != null) return fromJson.call(json)

    fields := Field:Obj[:]

    // map json properties to fields
    json.each |val, propName|
    {
      field := toField(type, propName)

      // skip unknown properties
      if (field == null) return

      fieldVal := decodeField(field, val)
      if (field.isConst) fieldVal = fieldVal.toImmutable
      fields[field] = fieldVal
      // fields[field] = decodeField(field, val)
    }

    // set the rawJson field
    rawField := type.field("rawJson", false)
    if (rawField != null) fields[rawField] = json.toImmutable

    // construct the object
    setter := Field.makeSetFunc(fields)
    return type.make([setter])
  }

  private Obj? decodeField(Field f, Obj? v)
  {
    if (v == null)
    {
      if (f.type.fits(List#) && !f.type.isNullable)
      {
        // convert non-nullable array fields to empty list if json is null
        return f.type.params["V"].emptyList
      }
      if (f.type.fits(Map#) && !f.type.isNullable)
      {
        // convert non-nullable map fields to empty map if json is null
        return Map(f.type)
      }
      return null
    }
    ftype := f.type.toNonNullable
    try
    {
      decoded := decodeVal(v, ftype)
      return decoded
      // return decodeVal(v, ftype)
    }
    catch (ParseErr err)
    {
      throw ParseErr("Cannot decode field ${f} with type ${f.type}", err)
    }
  }

  private static Field? toField(Type type, Str propName)
  {
    type.field(propName.decapitalize, false)
  }

  private static ParseErr valErr(Obj v, Type expected)
  {
    ParseErr("Expected val with type ${expected}, but got ${v.typeof}: $v")
  }
}
