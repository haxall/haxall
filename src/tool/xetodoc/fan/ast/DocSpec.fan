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
** AbstractDocSpec is the base class documentation type level specs and slots
**
@Js
abstract const class AbstractDocSpec
{
  ** Simple name of this instance
  abstract Str name()

  ** Documentation text
  abstract DocMarkdown doc()

  ** Effective metadata
  abstract DocDict meta()

  ** Spec flavor
  abstract SpecFlavor flavor()
}

**************************************************************************
** DocSpec
**************************************************************************

@Js
const class DocSpec : AbstractDocSpec, DocPage
{
  ** Constructor
  new make(|This| f)
  {
    f(this)
  }

  ** Page type
  override DocPageType pageType() { DocPageType.spec }

  ** URI relative to base dir to page
  override Uri uri() { DocUtil.qnameToUri(qname) }

  ** Title
  override Str title() { qname }

  ** Qualified name of this spec
  const Str qname

  ** Spec flavor
  const override SpecFlavor flavor

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

  ** Tags
  const DocTag[] tags

  ** Super type or null if this is 'sys::Obj'
  const DocTypeRef? base

  ** Supertype inheritance graph
  const DocTypeGraph supertypes

  ** Subtypes in this library
  const DocTypeGraph subtypes

  ** Child slots on this type (own and inherited)
  const Str:DocSlot slots

  ** Child globals on this type (own only)
  const Str:DocSlot globals

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
    obj := Str:Obj[:]
    obj.ordered   = true
    obj["page"]   = pageType.name
    obj["lib"]    = lib.encode
    obj["qname"]  = qname
    obj["flavor"] = flavor.name
    obj.addNotNull("srcLoc", srcLoc?.toStr)
    obj["doc"]    = doc.encode
    obj.addNotNull("meta", meta.encode)
    obj.addNotNull("tags", DocTag.encodeList(tags))
    obj.addNotNull("base", base?.encode)
    obj.addNotNull("supertypes", supertypes.encode)
    obj.addNotNull("subtypes", subtypes.encode)
    obj.addNotNull("slots", DocSlot.encodeMap(slots))
    obj.addNotNull("globals", DocSlot.encodeMap(globals))
    return obj
  }

  ** Decode from a JSON object tree
  static DocSpec doDecode(Str:Obj obj)
  {
    DocSpec
    {
      it.lib        = DocLibRef.decode(obj.getChecked("lib"))
      it.qname      = obj.getChecked("qname")
      it.flavor     = SpecFlavor.fromStr(obj.getChecked("flavor"))
      it.srcLoc     = DocUtil.srcLocDecode(obj)
      it.doc        = DocMarkdown.decode(obj.get("doc"))
      it.meta       = DocDict.decode(obj.get("meta"))
      it.tags       = DocTag.decodeList(obj.get("tags"))
      it.base       = DocTypeRef.decode(obj.get("base"))
      it.supertypes = DocTypeGraph.decode(obj.get("supertypes"))
      it.subtypes   = DocTypeGraph.decode(obj.get("subtypes"))
      it.slots      = DocSlot.decodeMap(obj.get("slots"))
      it.globals    = DocSlot.decodeMap(obj.get("globals"))
    }
  }
}

**************************************************************************
** DocSlot
**************************************************************************

**
** DocSlot is the documentation for a type slot
**
@Js
const class DocSlot : AbstractDocSpec
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

  ** Spec flavor
  override SpecFlavor flavor() { SpecFlavor.slot }

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

