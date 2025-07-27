//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using xetom

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
      case DocPageType.spec:     return genSpec(entry, entry.def)
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
      it.tags      = DocUtil.genTags(ns, x)
      it.specs     = summaries(specsToDoc(x))
      it.instances = summaries(x.instances)
      it.chapters  = chapterSummaries(x)
      it.readme    = entry.readme ?: DocMarkdown.empty
    }
  }

  DocLibDepend[] genDepends(Lib lib)
  {
    lib.depends.map |x| { DocLibDepend(DocLibRef(x.name, null), x.versions) }
  }

  DocSpec genSpec(PageEntry entry, Spec x)
  {
    srcLoc     := DocUtil.srcLoc(x)
    doc        := genSpecDoc(x)
    meta       := genDict(x.meta)
    base       := x.isCompound ? genTypeRef(x) : genTypeRef(x.base)
    slots      := genSlots(x)
    supertypes := genSupertypes(x)
    subtypes   := genSubtypes(x)
    return DocSpec(entry.libRef, x.qname, x.flavor, srcLoc, doc, meta, base, supertypes, subtypes, slots)
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
    acc := specsToDoc(x.lib).findAll |t|
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
    
    // Process backticks to normalize spec references
    normalizedStr := normalizeBackticks(str)
    
    return DocMarkdown(normalizedStr)
  }

  ** Normalize backticks from `name` to `qname | SpecFlavor::flavor`
  private Str normalizeBackticks(Str text)
  {
    result := text
    
    // Find and replace backtick patterns
    i := 0
    while (i < result.size)
    {
      start := result.index("`", i)
      if (start == null) break
      
      end := result.index("`", start + 1)
      if (end == null) break
      
      content := result[start+1..<end]
      replacement := processBacktick(content)
      
      if (replacement != null)
      {
        result = result[0..<start] + "`${replacement}`" + result[end+1..-1]
        i = start + replacement.size + 2
      }
      else
      {
        i = end + 1
      }
    }
    
    return result
  }

  ** Process single backtick content and return normalized format if resolvable
  private Str? processBacktick(Str content)
  {
    // Skip if already qualified (contains ::)
    if (content.contains("::")) return null
    
    // Skip URLs and other non-identifier content
    if (content.contains("/") || content.contains(".") || content.contains("@")) 
      return null
    
    // Try to resolve as spec in namespace by searching through all libraries
    try
    {
      // Search through all libraries for a spec with this simple name
      for (i := 0; i < ns.libs.size; i++)
      {
        lib := ns.libs[i]
        spec := lib.spec(content, false)
        if (spec != null) 
        {
          // Return new format: qname | SpecFlavor::flavor
          flavorStr := spec.flavor.toStr
          return "${spec.qname} | SpecFlavor::${flavorStr}"
        }
      }
    }
    catch (Err e) { /* ignore resolution errors */ }
    
    // Return null if not found (stays unchanged)
    return null
  }

}
