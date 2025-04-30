//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using xetoEnv
using haystack::Dict

**
** Generate DocPage for each entry
**
internal class GenPages: Step
{
  override Void run()
  {
    PageEntry? index
    eachPage |PageEntry entry|
    {
      if (entry.pageType == DocPageType.index)
        index = entry
      else
        entry.pageRef = genPage(entry)
    }

    // do index last
    index.pageRef = genIndex(index)
  }

  DocPage genPage(PageEntry entry)
  {
    switch (entry.pageType)
    {
      case DocPageType.lib:      return genLib(entry, entry.def)
      case DocPageType.type:     return genType(entry, entry.def)
      case DocPageType.global:   return genGlobal(entry, entry.def)
      case DocPageType.instance: return genInstance(entry, entry.def)
      case DocPageType.chapter:  return genChapter(entry, entry.def)
      default: throw Err(entry.pageType.name)
    }
  }

  DocIndex genIndex(PageEntry entry)
  {
    DocIndex.makeForNamespace(ns)
  }

  DocLib genLib(PageEntry entry, Lib x)
  {
    DocLib
    {
      it.name      = x.name
      it.version   = x.version
      it.doc       = genDoc(x.meta["doc"])
      it.meta      = genDict(x.meta)
      it.depends   = genDepends(x)
      it.types     = summaries(typesToDoc(x))
      it.globals   = summaries(x.globals)
      it.instances = summaries(x.instances)
      it.chapters  = chapterSummaries(x)
      it.readme    = entry.readme ?: DocMarkdown.empty
    }
  }

  DocLibDepend[] genDepends(Lib lib)
  {
    lib.depends.map |x| { DocLibDepend(DocLibRef(x.name, null), x.versions) }
  }

  DocType genType(PageEntry entry, Spec x)
  {
    doc        := genSpecDoc(x)
    meta       := genDict(x.meta)
    base       := x.isCompound ? genTypeRef(x) : genTypeRef(x.base)
    slots      := genSlots(x)
    supertypes := genSupertypes(x)
    subtypes   := genSubtypes(x)
    return DocType(entry.libRef, x.qname, doc, meta, base, supertypes, subtypes, slots)
  }

  DocTypeGraph genSupertypes(Spec x)
  {
    acc := Str:Int[:]
    acc.ordered = true
    doGenSupertypes(acc, x)
    types := acc.keys.map |qname->DocTypeRef| { DocSimpleTypeRef(qname) }

    edges := DocTypeGraphEdge[,]
    acc.each |index, qname|
    {
      edges.add(toSupertypeEdge(acc, ns.spec(qname)))
    }
    return DocTypeGraph(types, edges)
  }

  DocTypeGraphEdge toSupertypeEdge(Str:Int qnameToIndex, Spec spec)
  {
    if (spec.base == null) return DocTypeGraphEdge.obj
    if (!spec.isCompound)
    {
      index := qnameToIndex.getChecked(spec.base.qname)
      return DocTypeGraphEdge(DocTypeGraphEdgeMode.base, [index])
    }
    mode := spec.isOr ? DocTypeGraphEdgeMode.or : DocTypeGraphEdgeMode.and
    indexes := spec.ofs.map |x->Int| { qnameToIndex.getChecked(x.qname) }
    return DocTypeGraphEdge(mode, indexes)
  }

  Void doGenSupertypes(Str:Int acc, Spec? x)
  {
    if (x == null || acc[x.qname] != null) return
    acc[x.qname] = acc.size
    if (!x.isCompound)
    {
      doGenSupertypes(acc, x.base)
    }
    else
    {
      x.ofs.each |sup|
      {
        doGenSupertypes(acc, sup)
      }
    }
  }

  DocTypeGraph genSubtypes(Spec x)
  {
    acc := typesToDoc(x.lib).findAll |t|
    {
      if (t.isCompound)
        return t.ofs.any { it === x }
      else
        return t.base === x
    }
    if (acc.isEmpty) return DocTypeGraph.empty
    types := acc.map |s| { DocSimpleTypeRef(s.qname) }
    return DocTypeGraph(types, null)
  }

  DocGlobal genGlobal(PageEntry entry, Spec x)
  {
    doc := genSpecDoc(x)
    meta  := genDict(x.meta)
    type := genTypeRef(x.type)
    return DocGlobal(entry.libRef, x.qname, doc, meta, type)
  }

  DocInstance genInstance(PageEntry entry, Dict x)
  {
    qname    := x.id.id
    instance := genDict(x)
    return DocInstance(entry.libRef, qname, instance)
  }

  Str:DocSlot genSlots(Spec spec)
  {
    // only gen effective slots for top type slots
    // or a query such as points
    effective := spec.isType || spec.isQuery
    slots := effective ? spec.slots : spec.slotsOwn
    if (slots.isEmpty) return DocSlot.empty

    // create map of slots taking into account we may be
    // inheriting duplicated autoNamed slots such as "_0"
    autoNameCount := 0
    acc := Str:DocSlot[:]
    acc.ordered = true
    slots.each |slot|
    {
      d := genSlot(spec, slot)
      name := slot.name
      if (XetoUtil.isAutoName(name)) name = compiler.autoName(autoNameCount++)
      acc.add(name, d)
    }
    return acc
  }

  DocSlot genSlot(Spec parentType, Spec slot)
  {
    doc     := genSpecDoc(slot)
    meta    := genDict(slot.metaOwn)
    typeRef := genTypeRef(slot)
    parent  := slot.parent === parentType ? null : DocSimpleTypeRef(slot.parent.qname)
    base    := genSlotBase(slot)
    slots   := genSlots(slot)
    return DocSlot(slot.name, doc, meta, typeRef, parent, base, slots)
  }


  DocLink? genSlotBase(Spec slot)
  {
    base := slot.base
    if (base == null || !base.isGlobal) return null
    dis := base.qname
    uri := DocUtil.specToUri(base)
    return DocLink(uri, dis)
  }

  DocChapter genChapter(PageEntry entry, Str markdown)
  {
    DocChapter(entry.libRef, entry.key, genDoc(markdown))
  }

  DocDict genDict(Dict d)
  {
    // we type everything as sys::Dict for now
    spec := d.get("spec") as Ref
    type := spec == null ? DocTypeRef.dict : DocSimpleTypeRef(spec.id.toStr)
    acc := Str:Obj[:]
    d.each |v, n|
    {
      if (n == "doc") return // handled by DocBlock
      acc[n] = genVal(v)
    }
    return DocDict(type, acc)
  }

  DocVal genVal(Obj x)
  {
    if (x is Dict) return genDict(x)
    if (x is List) return genList(x)
    return genScalar(x)
  }

  DocList genList(Obj[] x)
  {
    DocList(DocTypeRef.list, x.map |item| { genVal(item) })
  }

  DocScalar genScalar(Obj x)
  {
    type := DocSimpleTypeRef(ns.specOf(x).qname)
    return DocScalar(type, x.toStr)
  }

  DocMarkdown genSpecDoc(Spec x)
  {
    genDoc(x.meta["doc"])
  }

  DocMarkdown genDoc(Obj? doc)
  {
    str := doc as Str ?: ""
    if (str.isEmpty) return DocMarkdown.empty
    return DocMarkdown(str)
  }
}

