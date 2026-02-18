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
    // add all extraPages pages first
    compiler.extraPages.each |page|
    {
      addPage(page, page.doc, page.tags)
    }

    // init document ns wrapper if not passed into compiler
    if (compiler.docns == null) compiler.docns = DocNamespace(ns, compiler.libs)
    this.docns = compiler.docns

    // each lib
    libGens := Lib[,]
    compiler.libs.each |lib|
    {
      if (DocUtil.isLibNoDoc(lib) && !compiler.testMode) return
      g := genLib(lib)
      libGens.add(lib)
    }

    // build index
    genIndex(libGens)

    // clear caches for gc
    docns = null
    docCache.clear
    specxCache.clear
  }

//////////////////////////////////////////////////////////////////////////
// Index
//////////////////////////////////////////////////////////////////////////

  private Void genIndex(Lib[] libs)
  {
    libPages := DocLib[,]
    pages.each |g|
    {
      if (g.page is DocLib) libPages.add(g.page)
    }

    page := DocIndex.makeForNamespace(ns, libPages)
    compiler.pages.add(page)
  }

//////////////////////////////////////////////////////////////////////////
// Lib
//////////////////////////////////////////////////////////////////////////

  private GenPage genLib(Lib lib)
  {
    // setup current lib
    this.lib      = lib
    this.libRef   = DocLibRef(lib.name, lib.version)
    this.libFuncs = null

    // specs
    specs     := genLibSpecs
    funcs     := genLibFuncs
    instances := genLibInstances
    chapters  := genLibChapters

    // create lib page
    page := DocLib
    {
      it.name      = lib.name
      it.title     = lib.name
      it.version   = lib.version
      it.doc       = genDoc(lib.meta["doc"], null)
      it.meta      = genDict(lib.meta, libMeta)
      it.depends   = genDepends(lib)
      it.tags      = DocUtil.genTags(ns, lib)
      it.specs     = specs
      it.funcs     = funcs
      it.instances = instances
      it.chapters  = chapters
    }

    // clear current lib
    this.lib    = null
    this.libRef = null

    // add to pages
    return addPage(page, page.doc, page.tags)
  }

  private DocSummary[] genLibSpecs()
  {
    summaries := DocSummary[,]
    lib.specs.each |x|
    {
      if (DocUtil.isSpecNoDoc(x)) return
      g := genSpec(x)
      summaries.add(g.summary)
    }
    return summaries
  }

  private DocSummary[] genLibFuncs()
  {
    if (libFuncs == null) return DocSummary#.emptyList
    acc := DocSummary[,]
    libFuncs.eachSlotOwn |s|
    {
      uri := DocUtil.qnameToUri(libFuncs.qname, s.name)
      acc.add(DocSummary(DocLink(uri, s.name), s.doc.summary))
    }
    return acc
  }

  private DocSummary[] genLibInstances()
  {
    summaries := DocSummary[,]
    lib.instances.each |x|
    {
      g := genInstance(x)
      summaries.add(g.summary)
    }
    return summaries
  }

  private DocSummary[] genLibChapters()
  {
    chapters  := DocChapter[,]
    summaries := DocSummary[,]
    mdIndex := null

    DocUtil.libEachMarkdownFile(lib) |uri, special|
    {
      md := lib.files.get(uri).readAllStr
      if (special == "index") { mdIndex = md; return }
      g := genChapter(uri, md)
      chapters.add(g.page)
      summaries.add(g.summary)
    }

    // if we had index.md, then use it for chapter summaries
    linker := CompilerDocLinker(compiler, lib, null)
    summaries = DocMarkdownParser(compiler, linker).parseChapterIndex(summaries, mdIndex)

    // now backpatch chapter prev/next
    backpatchChapterPrevNext(chapters, summaries)

    return summaries
  }

  private DocLibDepend[] genDepends(Lib lib)
  {
    lib.depends.map |x| { DocLibDepend(DocLibRef(x.name, null), x.versions) }
  }

//////////////////////////////////////////////////////////////////////////
// Spec
//////////////////////////////////////////////////////////////////////////

  private GenPage genSpec(Spec x)
  {
    page := genSpecPage(x)
    if (x.name == "Funcs") this.libFuncs = page
    return addPage(page, page.doc, page.tags)
  }

  private DocSpec genSpecPage(Spec x)
  {
    DocSpec
    {
     it.lib        = libRef
     it.qname      = x.qname
     it.flavor     = x.flavor
     it.srcLoc     = DocUtil.srcLoc(x)
     it.doc        = genSpecDoc(x)
     it.meta       = genDict(x.meta, specMeta)
     it.tags       = genSpecTags(x)
     it.base       = x.isCompound ? genTypeRef(x) : genTypeRef(x.base)
     it.supertypes = genSupertypes(x)
     it.subtypes   = genSubtypes(x)
     it.slots      = genSlots(x)
     it.globals    = genGlobals(x)
    }
  }

  private DocTag[] genSpecTags(Spec x)
  {
    acc := DocTag[,]
    acc.add(DocTags.fromFlavor(x.flavor))
    return acc
  }

  private DocTypeGraph genSupertypes(Spec x)
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

  private DocTypeGraphEdge toSupertypeEdge(Str:Int qnameToIndex, Spec spec)
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

  private Void doGenSupertypes(Str:Int acc, Spec? x)
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

  private DocTypeGraph genSubtypes(Spec x)
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

//////////////////////////////////////////////////////////////////////////
// Instance
//////////////////////////////////////////////////////////////////////////

  private Str:DocSlot genSlots(Spec spec)
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
      if (DocUtil.isSpecNoDoc(slot) && !spec.isQuery) return
      d := genSlot(spec, slot)
      name := slot.name
      if (XetoUtil.isAutoName(name)) name = compiler.autoName(autoNameCount++)
      acc.add(name, d)
    }
    return acc
  }

  private Str:DocSlot genGlobals(Spec spec)
  {
    map := spec.globalsOwn
    if (map.isEmpty) return DocSlot.empty
    acc := Str:DocSlot[:]
    acc.ordered = true
    map.each |slot|
    {
      acc[slot.name] = genSlot(spec, slot)
    }
    return acc
  }

  private DocSlot genSlot(Spec parentType, Spec slot)
  {
    loc     := DocUtil.srcLoc(slot)
    doc     := genSpecDoc(slot)
    meta    := genDict(slot.metaOwn, specMeta)
    typeRef := genTypeRef(slot)
    parent  := slot.parent === parentType ? null : DocSimpleTypeRef(slot.parent.qname)
    base    := genSlotBase(slot)
    slots   := genSlots(slot)
    return DocSlot(slot.name, doc, meta, typeRef, parent, base, slots)
  }

  private DocLink? genSlotBase(Spec slot)
  {
    base := slot.base
    if (base == null || !base.isGlobal) return null
    dis := base.qname
    uri := DocUtil.qnameToUri(base.qname)
    return DocLink(uri, dis)
  }

//////////////////////////////////////////////////////////////////////////
// Instance
//////////////////////////////////////////////////////////////////////////

  private GenPage genInstance(Dict x)
  {
    qname    := x.id.id
    instance := genDict(x, specxForDict(x))
    page     := DocInstance(libRef, qname, instance)
    return addPage(page, DocMarkdown.empty, null)
  }

//////////////////////////////////////////////////////////////////////////
// Chapter
//////////////////////////////////////////////////////////////////////////

  private GenPage genChapter(Uri uri, Str markdown)
  {
    // we backpatch the prev/next
    name  := uri.basename
    qname := lib.name + "::" + name
    doc   := docns.chapters(lib).get(name)
    page  := DocChapter(libRef, qname, doc.title, genDoc(markdown, doc), null, null)
    return addPage(page, page.doc,  null)
  }

  private Void backpatchChapterPrevNext(DocChapter[] chapters, DocSummary[] order)
  {
    order.each |cur, i|
    {
      chapter := chapters.find |x| { x.uri == cur.link.uri }
      if (chapter == null) return

      prev := i == 0 ? null : order[i-1]
      if (prev != null && prev.isHeading) prev = i-2 >= 0 ? order[i-2] : null

      next := order.getSafe(i+1)
      if (next != null && next.isHeading) next = order.getSafe(i+2)

      if (prev != null) DocChapter#prev->setConst(chapter, prev.link)
      if (next != null) DocChapter#next->setConst(chapter, next.link)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private DocDict genDict(Dict d, Spec? spec, DocLink? link := null)
  {
    // we type everything as sys::Dict for now
    type := spec == null ? DocTypeRef.dict : DocSimpleTypeRef(spec.id.toStr)
    acc := Str:Obj[:]
    d.each |v, n|
    {
      if (n == "doc") return // handled by DocBlock

      DocLink? slotLink := null
      if (spec != null)
      {
try
{
        slot := spec.members.getAll(n).first
        if (slot != null) slotLink = DocLink(DocUtil.specToUri(slot), null)
}
catch (Err e) echo("TODO: $e")
      }

      acc[n] = genVal(v, slotLink)
    }
    return DocDict(type, link, acc)
  }


  private DocVal genVal(Obj x, DocLink? link)
  {
    if (x is Dict) return genDict(x, specxForDict(x), link)
    if (x is List) return genList(x, link)
    return genScalar(x, link)
  }

  private DocList genList(Obj[] x, DocLink? link)
  {
    DocList(DocTypeRef.list, link, x.map |item| { genVal(item, null) })
  }

  private DocScalar genScalar(Obj x, DocLink? link)
  {
    type := DocSimpleTypeRef(ns.specOf(x).qname)
    return DocScalar(type, link, x.toStr)
  }

//////////////////////////////////////////////////////////////////////////
// Markdown
//////////////////////////////////////////////////////////////////////////

  private DocMarkdown genSpecDoc(Spec x)
  {
    doc := x.metaOwn.get("doc")
    if (doc != null) return genDoc(doc, x)
    if (x.isMember && x.type !== x.base) return genDoc(x.meta.get("doc"), x)
    return DocMarkdown.empty

  }

  private DocMarkdown genDoc(Obj? val, Obj? libDoc)
  {
    // handle empty
    str := (val as Str)?.trimToNull
    if (str == null) return DocMarkdown.empty

    // use cache since we have lots of repeats with inherited slots
    x := docCache[str]
    if (x == null)
    {
      linker := CompilerDocLinker(compiler, this.lib, libDoc)
      x = DocMarkdownParser(compiler, linker).parseDocMarkdown(str)
      docCache[str] = x
    }
    return x
  }

//////////////////////////////////////////////////////////////////////////
// Specx
//////////////////////////////////////////////////////////////////////////

  private once Spec libMeta()  { specx(ns.spec("sys::Lib")) }

  private once Spec specMeta() { specx(ns.spec("sys::Spec")) }

  private once Spec dictSpec() { specx(ns.spec("sys::Dict")) }

  private Spec specxForDict(Dict x)
  {
    spec := ns.specOf(x, false)
    if (spec == null) return dictSpec
    return specx(spec)
  }

  private Spec specx(Spec spec)
  {
    // use cache for specx since its expensive
    x := specxCache[spec.qname]
    if (x == null)
    {
      x = ns.specx(spec)
      specxCache[spec.qname] = x
    }
    return x
  }

//////////////////////////////////////////////////////////////////////////
// Generation
//////////////////////////////////////////////////////////////////////////

  private GenPage addPage(DocPage page, DocMarkdown doc, DocTag[]? tags)
  {
    summary := DocSummary(DocLink(page.uri, page.title), doc.summary, tags)
    x := GenPage(page, summary)
    if (pages[x.uri] != null)
    {
      err("Duplicate pages: $x.uri", FileLoc(x.uri.toStr))
    }
    else
    {
      pages[x.uri] = x
      compiler.pagesByUri.add(x.uri, x.page)
      compiler.pages.add(x.page)
    }
    return x
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private DocNamespace? docns
  private Uri:GenPage pages := [:]
  private Str:DocMarkdown docCache := [:]
  private Str:Spec specxCache := [:]
  private Lib? lib
  private DocSpec? libFuncs
  private DocLibRef? libRef
}

**************************************************************************
** GenPage
**************************************************************************

internal const class GenPage
{
  new make(DocPage p, DocSummary? s) { uri = p.uri; page = p; summary = s }
  const Uri uri
  const DocPage page
  const DocSummary? summary
}

