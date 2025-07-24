//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using haystack
using xetom

**
** DocSpec is the base class documentation all specs: types, globals, and slots
**
@Js
abstract const class DocSpec
{
  ** Simple name of this instance
  abstract Str name()

  ** Documentation text
  abstract DocMarkdown doc()

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
  new make(DocLibRef lib, Str qname, FileLoc? srcLoc, DocMarkdown doc, DocDict meta)
  {
    this.lib    = lib
    this.qname  = qname
    this.srcLoc = srcLoc
    this.doc    = doc
    this.meta   = meta
  }

  ** Title
  override Str title() { qname }

  ** Qualified name of this spec
  const Str qname

  ** Library name for this instance
  once Str libName() { XetoUtil.qnameToLib(qname) }

  ** Simple name of this instance
  once override Str name() { XetoUtil.qnameToName(qname) }

  ** Library for this page
  override const DocLibRef? lib

  ** Source code location
  const override FileLoc? srcLoc

  ** Documentation text
  const override DocMarkdown doc

  ** Effective meta data
  const override DocDict meta

  ** Encode to a JSON object tree
  override Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered   = true
    obj["page"]   = pageType.name
    obj["lib"]    = lib.encode
    obj["qname"]  = qname
    obj.addNotNull("srcLoc", srcLoc?.toStr)
    obj["doc"]    = doc.encode
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
  new make(DocLibRef lib, Str qname, FileLoc? srcLoc, DocMarkdown doc, DocDict meta, DocTypeRef? base, DocTypeGraph supertypes, DocTypeGraph subtypes, Str:DocSlot slots) : super(lib, qname, srcLoc, doc, meta)
  {
    this.base = base
    this.supertypes = supertypes
    this.subtypes = subtypes
    this.slots = slots
  }

  ** Page type
  override DocPageType pageType() { DocPageType.type }

  ** URI relative to base dir to page
  override Uri uri() { DocUtil.typeToUri(qname) }

  ** Super type or null if this is 'sys::Obj'
  const DocTypeRef? base

  ** Supertype inheritance graph
  const DocTypeGraph supertypes

  ** Subtypes in this library
  const DocTypeGraph subtypes

  ** Child slots on this type
  const Str:DocSlot slots

  ** Iterate only my own slots
  Void eachSlotOwn(|DocSlot| f)
  {
    slots.each |slot|
    {
      if (slot.parent == null) f(slot)
    }
  }

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
    lib        := DocLibRef.decode(obj.getChecked("lib"))
    qname      := obj.getChecked("qname")
    srcLoc     := DocUtil.srcLocDecode(obj)
    doc        := DocMarkdown.decode(obj.get("doc"))
    meta       := DocDict.decode(obj.get("meta"))
    base       := DocTypeRef.decode(obj.get("base"))
    supertypes := DocTypeGraph.decode(obj.get("supertypes"))
    subtypes   := DocTypeGraph.decode(obj.get("subtypes"))
    slots      := DocSlot.decodeMap(obj.get("slots"))
    return DocType(lib, qname, srcLoc, doc, meta, base, supertypes, subtypes, slots)
  }
}

**************************************************************************
** DocSimpleSpec
**************************************************************************

**
** DocSimpleSpec is the documentation for simple Xeto top-level specs: globals, functions, and meta specs
**
@Js
const class DocSimpleSpec : DocSpecPage
{
  ** Constructor
  new make(DocLibRef lib, Str qname, FileLoc? srcLoc, DocMarkdown doc, DocDict meta, DocTypeRef type, DocPageType pageType, Str:DocSlot slots := DocSlot.empty) : super(lib, qname, srcLoc, doc, meta)
  {
    this.type = type
    this.pageTypeVal = pageType
    this.slots = slots
  }

  ** Type of this spec
  const DocTypeRef type

  ** Page type
  override DocPageType pageType() { pageTypeVal }
  private const DocPageType pageTypeVal

  ** Slots for functions, empty for globals and metas
  const Str:DocSlot slots

  ** URI relative to base dir to page
  override Uri uri() 
  { 
    switch (pageTypeVal)
    {
      case DocPageType.global: return DocUtil.globalToUri(qname)
      case DocPageType.func:   return DocUtil.funcToUri(qname)
      case DocPageType.meta:   return DocUtil.globalToUri(qname).plusName("m_" + name)
      default: throw Err("Unsupported page type: $pageTypeVal")
    }
  }

  ** Encode to a JSON object tree
  override Str:Obj encode()
  {
    obj := super.encode
    obj["type"] = type.encode
    obj.addNotNull("slots", DocSlot.encodeMap(slots))
    return obj
  }

  ** Decode from a JSON object tree
  static DocSimpleSpec doDecode(Str:Obj obj)
  {
    lib      := DocLibRef.decode(obj.getChecked("lib"))
    qname    := obj.getChecked("qname")
    srcLoc   := DocUtil.srcLocDecode(obj)
    doc      := DocMarkdown.decode(obj.get("doc"))
    meta     := DocDict.decode(obj.get("meta"))
    type     := DocTypeRef.decode(obj.getChecked("type"))
    pageType := DocPageType.fromStr(obj.getChecked("page"))
    slots    := DocSlot.decodeMap(obj.get("slots"))
    return DocSimpleSpec(lib, qname, srcLoc, doc, meta, type, pageType, slots)
  }
}

** Alias for backward compatibility
@Js
const class DocGlobal : DocSimpleSpec
{
  new make(DocLibRef lib, Str qname, FileLoc? srcLoc, DocMarkdown doc, DocDict meta, DocTypeRef type) : super(lib, qname, srcLoc, doc, meta, type, DocPageType.global) {}
}

** Alias for backward compatibility  
@Js
const class DocFunc : DocSimpleSpec
{
  new make(DocLibRef lib, Str qname, FileLoc? srcLoc, DocMarkdown doc, DocDict meta, DocTypeRef type, Str:DocSlot slots) : super(lib, qname, srcLoc, doc, meta, type, DocPageType.func, slots) {}
}

** Meta spec documentation
@Js
const class DocMeta : DocSimpleSpec
{
  new make(DocLibRef lib, Str qname, FileLoc? srcLoc, DocMarkdown doc, DocDict meta, DocTypeRef type) : super(lib, qname, srcLoc, doc, meta, type, DocPageType.meta) {}
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
  new make(Str name, DocMarkdown doc, DocDict meta, DocTypeRef type, DocTypeRef? parent, DocLink? base, Str:DocSlot slots)
  {
    this.name   = name
    this.doc    = doc
    this.meta   = meta
    this.type   = type
    this.parent = parent
    this.base   = base
    this.slots  = slots
  }

  ** Simple name of this instance
  override const Str name

  ** Documentation for this slot
  override const DocMarkdown doc

  ** Declared own meta
  override const DocDict meta

  ** Type for this slot
  const DocTypeRef type

  ** Declared parent type if inherited, null if declared in containing type
  const DocTypeRef? parent

  ** Link to base used when this slot base is from global slot
  const DocLink? base

  ** Child slots on this type
  const Str:DocSlot slots

  ** Attempt to turn this slots default into a value (not accurate fidelity)
  Obj? toVal()
  {
    if (type.qname == "sys::Marker") return Marker.val
    val := meta.get("val") as DocVal
    if (val != null) return val.toVal
    if (!slots.isEmpty) return toDict
    return null
  }

  private Dict toDict()
  {
    acc := Str:Obj[:]
    acc.ordered = true
    acc["spec"] = Ref(type.qname)
    slots.each |slot| { acc.addNotNull(slot.name, slot.toVal) }
    return Etc.dictFromMap(acc)
  }

  ** Encode to a JSON object tree
  Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered  = true
    obj["doc"]   = doc.encode
    obj["type"]  = type.encode
    obj.addNotNull("parent", parent?.encode)
    obj.addNotNull("base", base?.encode)
    obj.addNotNull("meta", meta.encode)
    obj.addNotNull("slots", DocSlot.encodeMap(slots))
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
    doc    := DocMarkdown.decode(obj.get("doc"))
    type   := DocTypeRef.decode(obj.getChecked("type"))
    parent := DocTypeRef.decode(obj.get("parent"))
    base   := DocLink.decode(obj.get("base"))
    meta   := DocDict.decode(obj.get("meta"))
    slots  := DocSlot.decodeMap(obj.get("slots"))
    return make(name, doc, meta, type, parent, base, slots)
  }

  ** Decode map keyed by name
  static Str:DocSlot decodeMap([Str:Obj]? obj)
  {
    if (obj == null || obj.isEmpty) return DocSlot.empty
    return obj.map |x, n| { DocSlot.decode(n, x) }
  }
}
