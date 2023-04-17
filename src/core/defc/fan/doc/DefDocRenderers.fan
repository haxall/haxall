//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Jan 2021  Brian Frank  Creation
//

using compilerDoc
using web

class DefTopIndexRenderer : DefDocRenderer
{
  new make(DocEnv env, DocOutStream out, DocTopIndex doc) : super(env, out, doc) {}

  override Void writeContent()
  {
    // add manuals at top
    out.defSection("manuals").props
    env.spacesMap.vals.findType(DocPod#).sort.each |DocPod x|
    {
      out.propPod(x)
    }
    out.propsEnd.defSectionEnd

    // inline the appendix index
    DocAppendixIndexRenderer.doWriteContent(out, env.space("appendix"))

    // link to protos
    out.defSection("protos").props
    out.propQuick("proto/index", "Listing of all prototypes", "protos")
    out.propsEnd.defSectionEnd

    // list spec libs
    specs := env.spacesMap.vals.findType(DocDataLib#).sort
    if (!specs.isEmpty)
    {
      out.defSection("specs").props
      specs.each |DocDataLib x|
      {
        out.prop(DocLink(doc, x.index, x.qname), x.docSummary)
      }
      out.propsEnd.defSectionEnd
    }
  }
}

**************************************************************************
** DefPodIndexRenderer
**************************************************************************

class DefPodIndexRenderer : DefDocRenderer
{
  new make(DocEnv env, DocOutStream out, DocPodIndex doc) : super(env, out, doc) {}

  override Void writeContent()
  {
    doc := (DocPodIndex)doc
    isManual := doc.pod.isManual

    out.defSection(isManual ? "manual" : "pod")
      .h1.esc(doc.pod.name).h1End
      .p.esc(doc.pod.summary).pEnd
      .defSectionEnd

    if (isManual)
      writeManual(doc)
    else
      writeApi(doc)
  }

  private Void writeManual(DocPodIndex doc)
  {
    out.defSection("chapters").props
    doc.toc.each |obj|
    {
      if (obj is Str) { out.propTitle(obj); return }
      chapter := (DocChapter)obj
      out.prop(chapter, chapter.summary)
    }
    out.propsEnd.defSectionEnd
  }

  private Void writeApi(DocPodIndex doc)
  {
    if (doc.toc.isEmpty) return
    if (doc.toc.first isnot Str) throw Err("Internal toc error: $doc.pod.name | $doc.toc")
    doc.toc.each |obj, i|
    {
      if (obj is Str)
      {
        if (i > 0) out.propsEnd.defSectionEnd
        out.defSection(obj.toStr.decapitalize).props
      }
      else
      {
        type := (DocType)obj
        out.prop(DocLink(doc, type, type.name), type.doc.firstSentence)
      }
    }
    out.propsEnd.defSectionEnd

    if (doc.pod.podDoc != null) writeApiPodDoc(doc.pod.podDoc)
  }

  private Void writeApiPodDoc(DocChapter chapter)
  {
    out.defSection("docs")
    DefChapterRenderer(env, out, chapter).writeFandoc(chapter.doc)
    out.defSectionEnd
  }

  override Void buildNavData()
  {
    doc := (DocPodIndex)doc
    if (doc.pod.isManual)
      buildNavDataManual(doc)
    else
      buildNavDataApi(doc)
  }

  private Void buildNavDataManual(DocPodIndex doc)
  {
    doc.toc.each |obj|
    {
      if (obj is Str) return
      chapter := (DocChapter)obj
      navData.add(`$chapter.docName`, chapter.title)
    }
  }

  private Void buildNavDataApi(DocPodIndex doc)
  {
    doc.pod.types.each |t| { navData.add(`$t.name`, t.name, 0) }

    chapter := doc.pod.podDoc
    if (chapter != null)
    {
      navData.add(`#$chapter.headings.first.anchorId`, "Docs", 0)
      env.walkChapterToc(doc, chapter) |h, uri|
      {
        navData.add(uri, h.title, h.level.minus(1).max(1))
      }
    }
  }
}

**************************************************************************
** DefChapterRenderer
**************************************************************************

class DefChapterRenderer : DefDocRenderer
{
  new make(DocEnv env, DocOutStream out, DocChapter doc) : super(env, out, doc) {}

  override Void writePrevNext()
  {
    cur := (DocChapter)doc
    prev := cur.prev
    next := cur.next
    if (prev != null || next != null)
    {
      out.div("class='defc-nav'").ul
      if (prev != null) out.li("class='prev'").link(prev, "\u00ab $prev.title").liEnd; else out.li.w("&nbsp;").liEnd
      if (next != null) out.li("class='next'").link(next, "$next.title \u00bb").liEnd
      out.ulEnd.divEnd
    }

    return this
  }

  override Void writeContent()
  {
    chapter := (DocChapter)doc
    out.divEnd.div("class='defc-manual'") // end def-main, start new div

    out.h1("class='defc-chapter-title'").esc(chapter.title).h1End
    out.div; writeChapterTocLinks(doc); out.divEnd
    writeVideo(chapter)
    if (chapter.meta["layout"] == "slide")
      writeSlide(chapter)
    else
      out.fandoc(chapter.doc)
  }

  private Void writeVideo(DocChapter chapter)
  {
    vimeo := chapter.meta["vimeo"]
    if (vimeo == null) return
    if (!vimeo.startsWith("https"))
    {
      // backwards compatibility for vimeo video id
      vimeo = "https://player.vimeo.com/video/${vimeo}"
    }

    uri := vimeo.toUri.plusQuery([
      "title":    "0",
      "byline":   "0",
      "portrait": "0",
    ])

    out.w("<iframe style='border:1px solid #9f9f9f; margin: 1em 0;' src='").w(uri.toStr).w("'")
       .w(" width='960' height='540' frameborder='0'")
       .w(" webkitAllowFullScreen mozallowfullscreen allowFullScreen>")
       .w("</iframe>\n")
  }

  private Void writeSlide(DocChapter chapter)
  {
    out.div("class='defc-slide'")
    out.fandoc(chapter.doc)
    out.divEnd
  }

  override Void buildNavData()
  {
    env.walkChapterToc(doc, doc) |h, uri|
    {
      navData.add(uri, h.title, h.level.minus(2).max(0))
    }
  }


}

