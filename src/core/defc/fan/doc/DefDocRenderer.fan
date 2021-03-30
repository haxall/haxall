//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jun 2018  Brian Frank  Creation
//

using web
using fandoc::Image
using compilerDoc
using haystack

**
** DefDocRenderer is base class for defc renderers
**
abstract class DefDocRenderer : DocRenderer
{

  ** Constructor
  new make(DefDocEnv env, DocOutStream out, Doc doc) : super(env, out, doc) {}

  ** Return env as DefDocEnv
  override DefDocEnv env() { super.env }

  ** Return out as CDocOutStream
  override DocOutStream out() { super.out }

  ** Navigation menu/sidebar data
  DocNavData navData := DocNavData() { private set }

  ** Customize to insert defc-main div around body
  override Void writeDoc()
  {
    theme.writeStart(this)
    theme.writeBreadcrumb(this)
    writePrevNext
    out.div("class='defc-main'").nl
    writeContent
    out.divEnd
    writeNavData
    theme.writeEnd(this)
  }

  ** Customize secondary navigation below the breadcrumb
  virtual Void writePrevNext() {}

  ** Write the sidebar as a comment
  Void writeNavData()
  {
    buildNavData
    if (navData.isEmpty) return
    out.nl
       .w("<!-- defc-navData").nl
       .w(navData.encode)
       .w("-->").nl
  }

  ** Build the navigation menu/sidebar data
  virtual Void buildNavData() {}

  ** Write standard title header of a def
  Void writeDefHeader(Str name, Str title, Str? subtitle, CFandoc doc)
  {
    out.defSection(name)
       .h1.esc(title).h1End
    if (subtitle != null) out.h2.esc(subtitle).h2End
    out.fandoc(doc)
       .defSectionEnd
  }

  ** Write tag name/value pairs
  Void writeMetaSection(Def meta)
  {
    names := Etc.dictNames(meta).sort

    out.defSection("meta").props
    names.each |name|
    {
      val := meta[name]

      // specific tags handled specially
      switch (name)
      {
        case "doc":      val = val.toStr.isEmpty ? "\u2014" : "See above"
        case "children": val = "See below"
        case "enum":     val = "See below"
      }

      tag := env.def(name, false)
      if (tag != null && env.includeTagInMetaSection(meta, tag))
        out.prop(tag, val)
    }
    out.propsEnd.defSectionEnd
  }

  ** Write a list of defs
  Void writeListSection(Str name, DocDef[] defs, Bool justName := false)
  {
    if (defs.isEmpty) return
    out.defSection(name).props
    defs.each |def| { out.propDef(def, justName ? def.name : def.dis) }
    out.propsEnd.defSectionEnd
  }

  ** Write children prototypes section
  Void writeProtosSection(DocProto[] protos)
  {
    if (protos.isEmpty) return
    out.defSection("children").props
    protos.each |proto| { out.propProto(proto) }
    out.propsEnd.defSectionEnd
  }

  ** Write flatten list of chapter links as section
  Void writeChapterTocSection(Str name, Doc? target)
  {
    if (target == null) return
    out.defSection(name)
    writeChapterTocLinks(target)
    out.defSectionEnd
  }

  ** Write the chapter links (container element not written)
  Void writeChapterTocLinks(Doc target)
  {
    first := true
    env.walkChapterTocTopOnly(this.doc, target) |h, uri|
    {
      if (first)
      {
        uri = env.linkUri(DocLink(this.doc, target, h.title, null))
        first = false
      }
      else
      {
        out.w(" \u2022 ")
      }
      out.a(uri).esc(h.title).aEnd
    }
  }

  override Void onFandocImage(Image elem, DocLoc loc)
  {
    try
    {
      if (elem.uri.startsWith("http:") ||
          elem.uri.startsWith("https:")) return

      res := env.imageLink(doc, elem.uri, loc)
      if (res != null) out.resFiles[res.qname] = res
    }
    catch (Err e)
    {
      onFandocErr(e, loc)
    }
  }

  override Void onFandocErr(Err e, DocLoc loc)
  {
    msg := (e.typeof == Err# || e.typeof == DocErr#) ? e.msg : e.toStr
    echo("ERROR: $loc: $msg")
  }
}

