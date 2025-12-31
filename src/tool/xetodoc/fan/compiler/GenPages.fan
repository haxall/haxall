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
    // each lib
    libGens := GenPage[,]
    compiler.libs.each |lib|
    {
      if (DocUtil.isLibNoDoc(lib)) return
      g := genLib(lib)
      libGens.add(g)
    }

    // build index
    genIndex(libGens)
  }

//////////////////////////////////////////////////////////////////////////
// Index
//////////////////////////////////////////////////////////////////////////

  private Void genIndex(GenPage[] libs)
  {
   // TOOD
    page := DocIndex.makeForNamespace(ns)
    compiler.pages.add(page)
  }

//////////////////////////////////////////////////////////////////////////
// Lib
//////////////////////////////////////////////////////////////////////////

  private GenPage genLib(Lib lib)
  {
    // lib reference for child pages
    libRef :=  DocLibRef(lib.name, lib.version)

    // specs
    specs := DocSummary[,]
    lib.specs.each |x|
    {
      if (DocUtil.isSpecNoDoc(x)) return
      g := genSpec(libRef, x)
      specs.add(g.summary)
    }

    // instances
    instances := DocSummary[,]
    lib.instances.each |x|
    {
      g := genInstance(libRef, x)
      instances.add(g.summary)
    }

    // chapters
    chapters := DocSummary[,]
    DocUtil.libEachMarkdownFile(lib) |uri, special|
    {
      if (special != null) { echo("TODO: markdown special $uri"); return }
      g := genChapter(libRef, uri, lib.files.get(uri).readAllStr)
      chapters.add(g.summary)
    }

    // generate lib page
    page := DocLib
    {
      it.name      = lib.name
      it.version   = lib.version
      it.doc       = genDoc(lib.meta["doc"])
      it.meta      = genDict(lib.meta)
      it.depends   = genDepends(lib)
      it.tags      = DocUtil.genTags(ns, lib)
      it.specs     = specs
      it.instances = instances
      it.chapters  = chapters
    }

    // generate lib summary
    summary := DocSummary(DocLink(page.uri, lib.name), page.doc, page.tags)

    // add to pages
    return addPage(page, summary)
  }

  private DocLibDepend[] genDepends(Lib lib)
  {
    lib.depends.map |x| { DocLibDepend(DocLibRef(x.name, null), x.versions) }
  }

//////////////////////////////////////////////////////////////////////////
// Spec
//////////////////////////////////////////////////////////////////////////

  private GenPage genSpec(DocLibRef lib, Spec x)
  {
    page  := genSpecPage(lib, x)
    summary := DocSummary(DocLink(page.uri, x.name), page.doc, page.tags)
    return addPage(page, summary)
  }

  private DocSpec genSpecPage(DocLibRef lib, Spec x)
  {
    DocSpec
    {
     it.lib        = lib
     it.qname      = x.qname
     it.flavor     = x.flavor
     it.srcLoc     = DocUtil.srcLoc(x)
     it.doc        = genSpecDoc(x)
     it.meta       = genDict(x.meta)
     it.tags       = genSpecTags(x)
     it.base       = x.isCompound ? genTypeRef(x) : genTypeRef(x.base)
     it.supertypes = genSupertypes(x)
     it.subtypes   = genSubtypes(x)
     it.slots      = genSlots(x)
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
    uri := DocUtil.qnameToUri(base.qname)
    return DocLink(uri, dis)
  }

//////////////////////////////////////////////////////////////////////////
// Instance
//////////////////////////////////////////////////////////////////////////

  GenPage genInstance(DocLibRef lib, Dict x)
  {
    qname    := x.id.id
    instance := genDict(x)
    page     := DocInstance(lib, qname, instance)
    summary  := DocSummary(DocLink(page.uri, page.name), DocMarkdown.empty)
    return addPage(page, summary)
  }

//////////////////////////////////////////////////////////////////////////
// Chapter
//////////////////////////////////////////////////////////////////////////

  GenPage genChapter(DocLibRef lib,  Uri uri, Str markdown)
  {
    qname   := lib.name + "::" + uri.basename
    page    := DocChapter(lib, qname, genDoc(markdown))
    summary := DocSummary(DocLink(page.uri, page.title), page.doc)
    return addPage(page, summary)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  DocDict genDict(Dict d, DocLink? link := null)
  {
    // we type everything as sys::Dict for now
    spec := ns.specOf(d, false)
    type := spec == null ? DocTypeRef.dict : DocSimpleTypeRef(spec.id.toStr)
    acc := Str:Obj[:]
    d.each |v, n|
    {
      if (n == "doc") return // handled by DocBlock

      DocLink? slotLink := null
      slot := spec?.member(n, false)
      if (slot != null) slotLink = DocLink(DocUtil.specToUri(slot), null)

      acc[n] = genVal(v, slotLink)
    }
    return DocDict(type, link, acc)
  }


  private DocVal genVal(Obj x, DocLink? link)
  {
    if (x is Dict) return genDict(x, link)
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
    genDoc(x.meta["doc"])
  }

  private DocMarkdown genDoc(Obj? doc)
  {
    str := doc as Str ?: ""
    if (str.isEmpty) return DocMarkdown.empty
    return DocMarkdown(str)
  }

  /*
  private Void parseLibIndex(PageEntry entry)
  {
    if (entry.mdIndex == null) return

    lib := entry.lib
    loc := FileLoc("$entry.key index.md")
    try
    {
      //
      // we expect index.md to be a specific format of bullet lists:
      //
      // # Section Title
      // - [Foo](Foo.md): foo summary
      // - [Bar](Bar.md): bar summary
      //
      doc := entry.mdIndex.parse
      DocTag[]? tags := null
      order := 0
      doc.eachChild |node|
      {
        if (node is Heading)
        {
          text := textRend.render(node)
          tags = [DocTag.intern(text)]
        }
        else if (node is ListBlock)
        {
          node.eachChild |ListItem item|
          {
            parseLibIndexItem(lib, tags, item.firstChild, loc, order++)
          }
        }
      }
    }
    catch (Err e)
    {
      err("Cannot parseLibIndex", loc, e)
    }
  }

  private Void parseLibIndexItem(Lib lib, DocTag[]? tags, Node para, FileLoc loc, Int order)
  {
    // get the link as first node
    link := para.firstChild as Link

    // parse [link]: summary
    text := textRend.render(para)
    colon := text.index(":")
    if (colon != null) text = text[colon+1..-1].trim
    text = text.capitalize

    // if no link report warning
    if (link == null) return compiler.warn("Invalid lib index item: $text", loc)

    // find the chapter
    chapterName := link.destination
    if (chapterName.endsWith(".md")) chapterName = chapterName[0..-4]
    chapter := this.chapter(lib, chapterName)
    if (chapter == null) return compiler.warn("Unknown chapter name: $chapterName", loc)

    // set chapter summary
    chapter.summaryRef = DocSummary(chapter.summary.link, DocMarkdown(text), tags)
    chapter.order = order
  }

  private TextRenderer textRend := TextRenderer()
  */
//////////////////////////////////////////////////////////////////////////
// Generation
//////////////////////////////////////////////////////////////////////////

  private GenPage addPage(DocPage page, DocSummary summary)
  {
    x := GenPage(page, summary)
    if (pages[x.uri] != null)
    {
      err("Duplicate pages: $x.uri", FileLoc(x.uri.toStr))
    }
    else
    {
      pages[x.uri] = x
      compiler.pages.add(x.page)
    }
    return x
  }

  private Uri:GenPage pages := [:]
}

**************************************************************************
** GenPage
**************************************************************************

internal class GenPage
{
  new make(DocPage p, DocSummary? s) { uri = p.uri; page = p; summary = s }
  const Uri uri
  const DocPage page
  const DocSummary? summary
}

