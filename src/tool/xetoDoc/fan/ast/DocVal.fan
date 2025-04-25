//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Sep 2024  Brian Frank  Creation
//

using haystack

**
** DocVal models values stored in meta and instances
**
@Js
abstract const class DocVal
{

  ** Return if this is a scalar value
  virtual Bool isScalar() { false }

  ** Get this value as a DocSclar or raise exeption if not scalar
  virtual DocScalar asScalar() { throw Err("Not scalar: $typeof") }

  ** Return if this is a list value
  virtual Bool isList() { false }

  ** Get this value as a DocList or raise exeption if not list
  virtual DocList asList()  { throw Err("Not list: $typeof") }

  ** Return if this is a dict value
  virtual Bool isDict() { false }

  ** Get this value as a DocDict or raise exeption if not dict
  virtual DocDict asDict() { throw Err("Not dict: $typeof") }

  ** Type of this value
  abstract DocTypeRef type()

  ** Attempt to turn this slots default into a value (not accurate fidelity)
  virtual Obj? toVal() { null }

  ** Encode to a JSON object tree
  Obj? encodeVal()
  {
    acc := Str:Obj[:]
    acc.ordered = true
    acc["type"] = type.encode
    if (isScalar) acc["scalar"] = asScalar.scalar
    else if (isDict) acc["dict"] = asDict.dict.map |v| { v.encodeVal }
    else acc["list"] = asList.list.map |v| { v.encodeVal }
    return acc
  }

  ** Decode from a JSON object tree
  static DocVal decodeVal(Str:Obj obj)
  {
    type := DocTypeRef.decode(obj.getChecked("type"))

    scalar := obj["scalar"]
    if (scalar != null) return DocScalar(type, scalar)

    list := obj["list"] as Obj[]
    if (list != null) return DocList(type, list.map |x| { decodeVal(x) })

    dict := (Str:Obj)obj.getChecked("dict")
    return DocDict(type, dict.map |v, n| { decodeVal(v) })
  }

}

**************************************************************************
** DocScalar
**************************************************************************

@Js
const class DocScalar : DocVal
{
  ** Cosntructor
  new make(DocTypeRef type, Str scalar)
  {
    this.type   = type
    this.scalar = scalar
  }

  ** Type of this value
  const override DocTypeRef type

  ** String encoding of the scalar
  const Str scalar

  ** Return true
  override Bool isScalar() { true }

  ** Return this
  override DocScalar asScalar() { this }

  ** Attempt to turn this value into Fantom object (not accurate fidelity)
  override Obj? toVal() { doVal ?: scalar }
  private Obj? doVal()
  {
    switch (type.qname)
    {
      case "sys::Number": return Number.fromStr(scalar, false)
      case "sys::Date":   return Date.fromStr(scalar, false)
      case "sys::Time":   return Time.fromStr(scalar, false)
    }
    return null
  }
}

**************************************************************************
** DocList
**************************************************************************

@Js
const class DocList : DocVal
{
  ** Cosntructor
  new make(DocTypeRef type,  DocVal[]  list)
  {
    this.type = type
    this.list = list
  }

  ** Type of this value
  const override DocTypeRef type

  ** Lsit of values
  const DocVal[] list

  ** Return true
  override Bool isList() { true }

  ** Return this
  override DocList asList() { this }
}

