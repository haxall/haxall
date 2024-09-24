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
  ** Qualified name of this spec
  abstract Str qname()

  ** Library name for this instance
  abstract Str libName()

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
  const override Str qname

  ** Library name for this instance
  override once Str libName() { XetoUtil.qnameToLib(qname) }

  ** Simple name of this instance
  override once Str name() { XetoUtil.qnameToName(qname) }

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
  new make(Uri uri, Str qname, DocBlock doc, DocTypeRef? base) : super(uri, qname, doc)
  {
    this.base = base
  }

  ** Page type
  override DocPageType pageType() { DocPageType.type }

  ** Super type or null if this is 'sys::Obj'
  const DocTypeRef? base

  ** Encode to a JSON object tree
  override Str:Obj encode()
  {
    obj := super.encode
    obj.addNotNull("base", base?.encode)
    return obj
  }

  ** Decode from a JSON object tree
  static DocType doDecode(Str:Obj obj)
  {
    uri   := Uri.fromStr(obj.getChecked("uri"))
    qname := obj.getChecked("qname")
    doc   := DocBlock.decode(obj.get("doc"))
    base  := DocTypeRef.decode(obj.get("base"))
    return DocType(uri, qname, doc, base)
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
  ** Qualified name
  override Str qname() { "TODO"  }

  ** Library name for this instance
  override once Str libName() { "TODO" }

  ** Simple name of this instance
  override once Str name() { "TODO"  }

  ** Documentation for this slot
  override once DocBlock doc() { DocBlock.empty }
}

