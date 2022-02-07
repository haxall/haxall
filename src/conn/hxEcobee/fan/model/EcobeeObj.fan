//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   02 Feb 2022  Matthew Giannini  Creation
//

using util

**
** Base class for all Ecobee objects
**
abstract const class EcobeeObj
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make() { }

  ** Return the unique object id for this object if it has one; otherwise return null
  virtual Str? id() { null }

  ** If this object was constructed from a web response, this is the raw
  ** decoded JSON object.
  const [Str:Obj?]? resJson := null

  ** Get the name of the json key for this object when it is stored as the
  ** value in a json map.
  **
  **   Example:
  **   EcobeeSelection => selection
  virtual Str jsonKey() { typeof.name[("Ecobee".size)..-1].decapitalize }

  ** Encode this object to a JSON string
  virtual Str encode() { EcobeeEncoder.jsonStr(this) }
}

**************************************************************************
** EcobeeDecoder
**************************************************************************

@NoDoc final class EcobeeDecoder
{
  new make() { }

  Obj? decode(Obj? json, Type asType)
  {
    if (json == null)         return null
    if (Str# === asType)      return decodeStr(json)
    if (Bool# === asType)     return decodeBool(json)
    if (Int# === asType)      return decodeNum(json).toInt
    if (Float# === asType)    return decodeNum(json).toFloat
    if (DateTime# === asType) return decodeDateTime(json)
    if (Date# === asType)     return decodeDate(json)
    if (asType.fits(List#))   return decodeList(json, asType)
    if (asType.fits(Map#))    return decodeMap(json, asType)
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
    if (v is Str) return Bool.fromStr(v)
    throw valErr(v, Bool#)
  }

  private Num decodeNum(Obj v)
  {
    if (v is Num) return v
    throw valErr(v, Num#)
  }

  private DateTime decodeDateTime(Obj v)
  {
    // only can decode to UTC
    if (v is Str)
    {
      return DateTime.fromLocale(v, "YYYY-MM-DD hh:mm:ss", TimeZone.utc)
    }
    throw valErr(v, DateTime#)
  }

  private Date decodeDate(Obj v)
  {
    if (v is Str) return Date.fromStr(v)
    throw valErr(v, Date#)
  }

  private List decodeList(Obj json, Type listType)
  {
    v := json as List
    if (v == null) throw valErr(json, listType)

    of  := listType.params["V"]
    acc := List.make(of, v.size)
    v.each |item| { acc.add(decode(item, of)) }
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
      map[decode(key, keyType)] = decode(val, valType)
    }
    return map
  }

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
      decoded := decode(v, ftype)
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

**************************************************************************
** EcobeeEncoder
**************************************************************************

** Encode an ecobee object to JSON
class EcobeeEncoder
{
  static Obj? encode(Obj? val) { EcobeeEncoder().encodeVal(val) }

  static Str jsonStr(Obj? val) { JsonOutStream.writeJsonToStr(encode(val)) }

  new make()
  {
  }

  Obj? encodeVal(Obj? val)
  {
    if (val == null) return null
    if (val is Str)  return val
    if (val is Bool) return val
    if (val is Num)  return val
    if (val is Enum) return encodeEnum(val)
    if (val is List) return encodeList(val)
    if (val is Map)  return encodeMap(val)
    return encodeObj(val)
  }

  Obj encodeObj(EcobeeObj obj)
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

      // don't encode false properties
      if (val == false) return

      json[toPropName(field)] = encodeVal(val)
    }
    return json
  }

  Obj encodeEnum(Enum val)
  {
    val.toStr
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
    if (field.isStatic) return false
    if (field.parent == EcobeeObj#) return false
    return true
  }

  private static Str toPropName(Field field)
  {
    field.name
  }
}