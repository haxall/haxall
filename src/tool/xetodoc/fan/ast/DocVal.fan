//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Sep 2024  Brian Frank  Creation
//

using xeto
using haystack

**
** DocVal models values stored in meta and instances
**
@Js
abstract const class DocVal
{
  ** Constructor
  new make(DocTypeRef type, DocLink? link := null)
  {
    this.type = type
    this.linkRef = link
  }

  ** Type of this value
  const DocTypeRef type

  ** Hyperlink to use for this value. This is typically the slot definition
  ** for Lib/Spec metadata or the dict slot type for instances.  Or if not
  ** available then we fallback to link to value type.
  DocLink? link() { linkRef ?: type.link }
  private const DocLink? linkRef

  ** Return if this is a scalar value
  virtual Bool isScalar() { false }

  ** Return if marker scalar
  virtual Bool isMarker() { false }

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

  ** Attempt to turn this slots default into a value (not accurate fidelity)
  abstract Obj? toVal()

  ** Encode to a JSON object tree
  Obj? encodeVal()
  {
    acc := Str:Obj[:]
    acc.ordered = true
    acc["type"] = type.encode
    if (linkRef != null) acc["link"] = linkRef.encode
    if (isScalar) acc["scalar"] = asScalar.scalar
    else if (isDict) acc["dict"] = asDict.dict.map |v| { v.encodeVal }
    else acc["list"] = asList.list.map |v| { v.encodeVal }
    return acc
  }

  ** Decode from a JSON object tree
  static DocVal decodeVal(Str:Obj obj)
  {
    type := DocTypeRef.decode(obj.getChecked("type"))

    link := DocLink.decode(obj.get("link"))

    scalar := obj["scalar"]
    if (scalar != null) return DocScalar(type, link, scalar)

    list := obj["list"] as Obj[]
    if (list != null) return DocList(type, link, list.map |x| { decodeVal(x) })

    dict := (Str:Obj)obj.getChecked("dict")
    return DocDict(type, link, dict.map |v, n| { decodeVal(v) })
  }

}

**************************************************************************
** DocScalar
**************************************************************************

@Js
const class DocScalar : DocVal
{
  ** Marker value
  static once DocScalar marker() { make(DocTypeRef.marker, null, Marker.val.toStr) }

  ** Construct generic string
  static DocScalar str(Str v) { make(DocTypeRef.str, null, v) }

  ** Constructor
  new make(DocTypeRef type, DocLink? link, Str scalar) : super(type, link)
  {
    this.scalar = scalar
  }

  ** String encoding of the scalar
  const Str scalar

  ** Return true
  override Bool isScalar() { true }

  ** Return this
  override DocScalar asScalar() { this }

  ** Return if marker scalar
  override Bool isMarker() { type.qname == "sys::Marker" }

  ** Attempt to turn this value into Fantom object (not accurate fidelity)
  override Obj? toVal() { doVal ?: scalar }
  private Obj? doVal()
  {
    switch (type.qname)
    {
      case "sys::Marker": return Marker.val
      case "sys::Number": return Number.fromStr(scalar, false)
      case "sys::Date":   return Date.fromStr(scalar, false)
      case "sys::Time":   return Time.fromStr(scalar, false)
      case "sys::Ref":    return Ref.fromStr(scalar, false)
      case "sys::Uri":    return Uri.fromStr(scalar, false)
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
  new make(DocTypeRef type, DocLink? link, DocVal[]  list) : super(type, link)
  {
    this.list = list
  }

  ** Lsit of values
  const DocVal[] list

  ** Return true
  override Bool isList() { true }

  ** Return this
  override DocList asList() { this }

  ** Map list items to val
  override Obj? toVal() { list.map |x| { x.toVal } }
}

