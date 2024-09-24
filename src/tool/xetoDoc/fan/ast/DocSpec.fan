//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using xetoEnv

**
** DocSpec is the base class documentation all specs: types, globals, and slots
**
@Js
abstract const class DocSpec
{
  ** Simple name of this instance
  abstract Str name()

  ** Documentation text
  abstract DocBlock doc()
}

**************************************************************************
** DocSpecPage
**************************************************************************

@Js
abstract const class DocSpecPage : DocSpec, DocPage
{
  ** Constructor
  new make(Uri uri, Str qname, DocBlock doc)
  {
    this.uri   = uri
    this.qname = qname
    this.doc   = doc
  }

  ** URI relative to base dir to page
  const override Uri uri

  ** Qualified name of this spec
  const Str qname

  ** Library name for this instance
  once Str libName() { XetoUtil.qnameToLib(qname) }

  ** Simple name of this instance
  once override Str name() { XetoUtil.qnameToName(qname) }

  ** Documentation text
  const override DocBlock doc

  ** Encode to a JSON object tree
  override Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered  = true
    obj["page"]  = pageType.name
    obj["uri"]   = uri.toStr
    obj["qname"] = qname
    obj["doc"]   = doc.encode
    return obj
  }
}

**************************************************************************
** DocType
**************************************************************************

**
** DocType is the documentation for a Xeto top-level type
**
@Js
const class DocType : DocSpecPage
{
  ** Constructor
  new make(Uri uri, Str qname, DocBlock doc, DocTypeRef? base, Str:DocSlot slots) : super(uri, qname, doc)
  {
    this.base = base
    this.slots = slots
  }

  ** Page type
  override DocPageType pageType() { DocPageType.type }

  ** Super type or null if this is 'sys::Obj'
  const DocTypeRef? base

  ** Child slots on this type
  const Str:DocSlot slots

  ** Encode to a JSON object tree
  override Str:Obj encode()
  {
    obj := super.encode
    obj.addNotNull("base", base?.encode)
    obj.addNotNull("slots", DocSlot.encodeMap(slots))
    return obj
  }

  ** Decode from a JSON object tree
  static DocType doDecode(Str:Obj obj)
  {
    uri   := Uri.fromStr(obj.getChecked("uri"))
    qname := obj.getChecked("qname")
    doc   := DocBlock.decode(obj.get("doc"))
    base  := DocTypeRef.decode(obj.get("base"))
    slots := DocSlot.decodeMap(obj.get("slots"))
    return DocType(uri, qname, doc, base, slots)
  }
}

**************************************************************************
** DocGlobal
**************************************************************************

**
** DocGlobal is the documentation for a Xeto top-level global
**
@Js
const class DocGlobal : DocSpecPage
{
  ** Constructor
  new make(Uri uri, Str qname, DocBlock doc, DocTypeRef type) : super(uri, qname, doc)
  {
    this.type = type
  }

  ** Type of this global
  const DocTypeRef type

  ** Page type
  override DocPageType pageType() { DocPageType.global }

  ** Encode to a JSON object tree
  override Str:Obj encode()
  {
    obj := super.encode
    obj["type"] = type.encode
    return obj
  }

  ** Decode from a JSON object tree
  static DocGlobal doDecode(Str:Obj obj)
  {
    uri   := Uri.fromStr(obj.getChecked("uri"))
    qname := obj.getChecked("qname")
    doc   := DocBlock.decode(obj.get("doc"))
    type  := DocTypeRef.decode(obj.getChecked("type"))
    return DocGlobal(uri, qname, doc, type)
 }
}

**************************************************************************
** DocSlot
**************************************************************************

**
** DocSlot is the documentation for a type slot
**
@Js
const class DocSlot : DocSpec
{
  ** Empty map of slots
  static const Str:DocSlot empty := Str:DocSlot[:]

  ** Constructor
  new make(Str name, DocBlock doc, DocTypeRef type, DocTypeRef? parent)
  {
    this.name   = name
    this.doc    = doc
    this.type   = type
    this.parent = parent
  }

  ** Simple name of this instance
  override const Str name

  ** Documentation for this slot
  override const DocBlock doc

  ** Type for this slot
  const DocTypeRef type

  ** Declared parent type if inherited
  const DocTypeRef? parent

  ** Encode to a JSON object tree
  Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered  = true
    obj["doc"]   = doc.encode
    obj["type"]  = type.encode
    obj.addNotNull("parent", parent?.encode)
    return obj
  }

  ** Decode map keyed by name
  static Obj? encodeMap(Str:DocSlot map)
  {
    if (map.isEmpty) return null
    return map.map |x| { x.encode }
  }

  ** Decode from a JSON object tree
  static DocSlot decode(Str name, Str:Obj obj)
  {
    doc    := DocBlock.decode(obj.get("doc"))
    type   := DocTypeRef.decode(obj.getChecked("type"))
    parent := DocTypeRef.decode(obj.get("parent"))
    return make(name, doc, type, parent)
  }

  ** Decode map keyed by name
  static Str:DocSlot decodeMap([Str:Obj]? obj)
  {
    if (obj == null || obj.isEmpty) return DocSlot.empty
    return obj.map |x, n| { DocSlot.decode(n, x) }
  }
}

