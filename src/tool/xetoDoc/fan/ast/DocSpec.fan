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

  ** Effective metadata
  abstract DocDict meta()
}

**************************************************************************
** DocSpecPage
**************************************************************************

@Js
abstract const class DocSpecPage : DocSpec, DocPage
{
  ** Constructor
  new make(Str qname, DocBlock doc, DocDict meta)
  {
    this.qname = qname
    this.doc   = doc
    this.meta  = meta
  }

  ** URI relative to base dir to page
  override Uri uri() { DocUtil.qnameToUri(qname) }

  ** Qualified name of this spec
  const Str qname

  ** Library name for this instance
  once Str libName() { XetoUtil.qnameToLib(qname) }

  ** Simple name of this instance
  once override Str name() { XetoUtil.qnameToName(qname) }

  ** Documentation text
  const override DocBlock doc

  ** Effective meta data
  const override DocDict meta

  ** Encode to a JSON object tree
  override Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered  = true
    obj["page"]  = pageType.name
    obj["qname"] = qname
    obj["doc"]   = doc.encode
    obj.addNotNull("meta", meta.encode)
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
  new make(Str qname, DocBlock doc, DocDict meta, DocTypeRef? base, DocTypeGraph supertypes, DocTypeGraph subtypes, Str:DocSlot slots) : super(qname, doc, meta)
  {
    this.base = base
    this.supertypes = supertypes
    this.subtypes = subtypes
    this.slots = slots
  }

  ** Page type
  override DocPageType pageType() { DocPageType.type }

  ** Super type or null if this is 'sys::Obj'
  const DocTypeRef? base

  ** Supertype inheritance graph
  const DocTypeGraph supertypes

  ** Subtypes in this library
  const DocTypeGraph subtypes

  ** Child slots on this type
  const Str:DocSlot slots

  ** Encode to a JSON object tree
  override Str:Obj encode()
  {
    obj := super.encode
    obj.addNotNull("base", base?.encode)
    obj.addNotNull("supertypes", supertypes.encode)
    obj.addNotNull("subtypes", subtypes.encode)
    obj.addNotNull("slots", DocSlot.encodeMap(slots))
    return obj
  }

  ** Decode from a JSON object tree
  static DocType doDecode(Str:Obj obj)
  {
    qname      := obj.getChecked("qname")
    doc        := DocBlock.decode(obj.get("doc"))
    meta       := DocDict.decode(obj.get("meta"))
    base       := DocTypeRef.decode(obj.get("base"))
    supertypes := DocTypeGraph.decode(obj.get("supertypes"))
    subtypes   := DocTypeGraph.decode(obj.get("subtypes"))
    slots      := DocSlot.decodeMap(obj.get("slots"))
    return DocType(qname, doc, meta, base, supertypes, subtypes, slots)
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
  new make(Str qname, DocBlock doc, DocDict meta, DocTypeRef type) : super(qname, doc, meta)
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
    qname := obj.getChecked("qname")
    doc   := DocBlock.decode(obj.get("doc"))
    meta  := DocDict.decode(obj.get("meta"))
    type  := DocTypeRef.decode(obj.getChecked("type"))
    return DocGlobal(qname, doc, meta, type)
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
  new make(Str name, DocBlock doc, DocDict meta, DocTypeRef type, DocTypeRef? parent)
  {
    this.name   = name
    this.doc    = doc
    this.meta   = meta
    this.type   = type
    this.parent = parent
  }

  ** Simple name of this instance
  override const Str name

  ** Documentation for this slot
  override const DocBlock doc

  ** Declared own meta
  override const DocDict meta

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
    obj.addNotNull("meta", meta.encode)
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
    meta   := DocDict.decode(obj.get("meta"))
    return make(name, doc, meta, type, parent)
  }

  ** Decode map keyed by name
  static Str:DocSlot decodeMap([Str:Obj]? obj)
  {
    if (obj == null || obj.isEmpty) return DocSlot.empty
    return obj.map |x, n| { DocSlot.decode(n, x) }
  }
}

