//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Jun 2018  Brian Frank  Creation
//

using concurrent
using compilerDoc
using fandoc::Link
using haystack
using web

**
** DocLib is the documentation space for a CLib
**
const class DocLib : DocSpace
{
  internal new make(|This| f) { f(this) }

  const Lib def

  const Str name

  override Str spaceName() { "lib-$name" }

  override Str breadcrumb() { name }

  const DocLibIndex index

  DocLibManual? manual() { manualRef.val }
  const AtomicRef manualRef := AtomicRef()  // late bound externally

  const DocDef[] defs

  const CFandoc docSummary

  const CFandoc docFull

  override Doc? doc(Str docName, Bool checked := true)
  {
    if (docName == index.docName) return index
    if (docName == manual?.docName) return manual
    doc := defs.find |doc| { doc.docName == docName }
    if (doc != null) return doc
    if (checked) throw UnknownDocErr(docName)
    return null
  }

  override Void eachDoc(|Doc| f)
  {
    f(index)
    if (manual != null) f(manual)
    defs.each(f)
  }
}

**************************************************************************
** Lib Index Doc
**************************************************************************

const class DocLibIndex : DocDef
{
  new make(DocLib lib) : super(lib, CLoc.none, lib.def) {}
  override Str docName() { "index" }
  override Str title() { lib.name }
  override Bool isSpaceIndex() { true }
  override Type renderer() { DocLibIndexRenderer# }
}

**************************************************************************
** Lib Manual
**************************************************************************

const class DocLibManual : Doc
{
  new make(DocLib lib, DocChapter chapter) { this.lib = lib; this.chapter = chapter }
  const DocLib lib
  const DocChapter chapter
  override DocSpace space() { lib }
  override Str docName() { "doc" }
  override Str title() { lib.name }
  override Type renderer() { DocLibManualRenderer# }
  override DocHeading? heading(Str id, Bool checked := true)
  {
    chapter.heading(id, checked)
  }
}

**************************************************************************
** DocLibIndexRenderer
**************************************************************************

internal class DocLibIndexRenderer : DefDocRenderer
{
  new make(DocEnv env, WebOutStream out, DocLibIndex doc) : super(env, out, doc) {}

  override Void writeContent()
  {
    lib := ((DocLibIndex)doc).lib
    writeDefHeader("lib", lib.def.symbol.toStr, null, lib.docFull)
    writeMetaSection(lib.def)

    writeChapterTocSection("docs", lib.manual)

    out.trackToNavData = true

    terms := lib.defs.findAll { it.type.isTerm }
    if (!terms.isEmpty)
    {
      out.defSection("tags", "tags-index").props
      terms.each |term| { out.propDef(term) }
      out.propsEnd.defSectionEnd
    }

    env.ns.features.each |feature|
    {
      keys := lib.defs.findAll |x| { x.type.isKey && x.symbol.part(0) == feature.name }
      writeListSection(feature.name+"s", keys, true)
    }
  }
}

**************************************************************************
** DocLibManualRenderer
**************************************************************************

internal class DocLibManualRenderer : DefDocRenderer
{
  new make(DocEnv env, WebOutStream out, DocLibManual doc) : super(env, out, doc) {}

  override Void writeContent()
  {
    lib := ((DocLibManual)doc).lib
    chapter := lib.manual.chapter

    out.divEnd.div("class='defc-manual'") // end def-main, start new div

    out.h1("class='defc-chapter-title'").esc("lib $lib.name").h1End
    out.div; writeChapterTocLinks(doc); out.divEnd
    out.fandoc(chapter.doc)
  }

  override Void buildNavData()
  {
    env.walkChapterToc(doc, doc) |h, uri|
    {
      navData.add(uri, h.title, h.level.minus(2).max(0))
    }
  }
}

