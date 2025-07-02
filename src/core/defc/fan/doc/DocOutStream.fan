//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jun 2018  Brian Frank  Creation
//

using web
using compilerDoc
using xeto
using haystack

**
** DocOutStream extends WebOutStream with doc specific section/props
**
class DocOutStream : WebOutStream
{
  new make(OutStream out, Str:DocResFile resFiles) : super(out)
  {
    this.resFiles = resFiles
  }

//////////////////////////////////////////////////////////////////////////
// Sections
//////////////////////////////////////////////////////////////////////////

  This defSection(Str title, Str id := title)
  {
    if (trackToNavData && !title.isEmpty)
    {
      navUri := doc.isTopIndex ? `${doc.docName}#${id}` : `#${id}`
      navData.add(navUri, title, 0)
    }

    uri := doc != null ? env.linkSectionTitle(doc, id) : null
    h2("class='defc-main-heading' id='$id.toXml'")
    if (uri != null) a(uri).esc(title).aEnd
    else esc(title)
    return h2End.div("class='defc-main-section'")
  }

  This defSectionEnd()
  {
    nl.divEnd.nl
  }

//////////////////////////////////////////////////////////////////////////
// Prop Tables
//////////////////////////////////////////////////////////////////////////

  This props() { table("class='defc-props'") }

  This propsEnd() { tableEnd }

  This prop(Obj name, Obj? val)
  {
    if (val == null) return this
    tr.th.propName(name).thEnd
      .td.propVal(val).tdEnd
      .trEnd
    return this
  }

  This propName(Obj name)
  {
    if (name is Doc) name = docToLink(name)
    if (name is DocLink)
    {
      link := (DocLink)name
      uri := env.linkUri(link)
      a(uri).esc(link.dis).aEnd
      if (trackToNavData) navData.add(uri, link.dis, 1)
    }
    else
    {
      esc(name)
    }
    return this
  }

  This propVal(Obj? val)
  {
    if (val is Symbol)    return symbolVal(val)
    if (val is Uri)       return uriVal(val)
    if (val is List)      return listVal(val)
    if (val is Dict)      return dictVal(val)
    if (val is DocFandoc) return fandoc(val)
    if (val is DocLink)   return linkTo(val)
    return esc(Etc.valToDis(val))
  }

  private This listVal(List val)
  {
    val.each |v, i| { if (i > 0) w(", "); propVal(v) }
    return this
  }

  private This dictVal(Dict val)
  {
    w("{")
    i := 0
    val.each |v, n|
    {
      if (i > 0) w(", ")
      w(n)
      if (v != Marker.val) { w(":"); propVal(v) }
      i++
    }
    return w("}")
  }

  private This symbolVal(Symbol symbol)
  {
    def := env.def(symbol.toStr, false)
    if (def != null) return link(def)

    if (symbol.size == 2 && symbol.part(0) == "lib")
    {
      lib := env.lib(symbol.part(1), false)
      if (lib != null) return link(lib.index, symbol.toStr)
    }

    return esc(symbol.toStr)
  }

  private This uriVal(Uri uri)
  {
    uri.isAbs ? a(uri).esc(uri).aEnd : esc(uri.toStr)
  }

  This propDef(DocDef def, Str dis := def.dis, Int indentation := 0)
  {
    uri := env.linkUri(docToLink(def))
    if (trackToNavData) navData.add(uri, dis, indentation+1)
    tr.th.indent(indentation).a(uri).esc(dis).aEnd.thEnd
      .td.docSummary(def).tdEnd
      .trEnd
    return this
  }

  This propLib(DocLib lib, Str? frag := null)
  {
    prop(DocLink(doc, lib.index, lib.name, frag), lib.docSummary)
  }

  This propPod(DocPod pod)
  {
    prop(DocLink(doc, pod.index, pod.name), pod.summary)
  }

  This propProto(DocProto proto)
  {
    tr.th("colspan='2'").link(proto).thEnd.tr
  }

  This propQuick(Str path, Str summary, Str? dis := null)
  {
    toks := path.split('/')
    space := env.space(toks[0])
    doc := space.doc(toks[1])
    if (dis == null) dis = doc.docName.decapitalize
    prop(DocLink(this.doc, doc, dis), summary)
    return this
  }

  This propTitle(Str title)
  {
    tr.th("class='defc-prop-title' colspan='2'").esc(title).thEnd.trEnd
  }

  This indent(Int indentation)
  {
    indentation.times { w("&nbsp;&nbsp;&nbsp;&nbsp;") }
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Navigation
//////////////////////////////////////////////////////////////////////////

  Bool trackToNavData

  private once DocNavData navData() { ((DefDocRenderer)renderer).navData }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  This linkTo(DocLink link)
  {
    uri := env.linkUri(link)
    a(uri).esc(link.dis).aEnd
    return this
  }

  This linkDef(Def target, Str dis := target.symbol.toStr)
  {
    link(env.resolve(target), dis)
  }

  This link(Doc target, Str dis := target.title)
  {
    linkTo(docToLink(target, dis))
  }

  DocLink docToLink(Doc target, Str dis := target.title)
  {
    DocLink(this.doc, target, dis)
  }

//////////////////////////////////////////////////////////////////////////
// Doc -> Fandoc
//////////////////////////////////////////////////////////////////////////

  This docFull(DocDef def)
  {
    fandoc(def.docFull)
  }

  This docSummary(DocDef def)
  {
    fandoc(def.docSummary)
  }

  This fandoc(DocFandoc doc)
  {
    renderer.writeFandoc(doc)
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  // keep track of all imageLink resource files
  internal Str:DocResFile resFiles { private set }

  // wired up by DefDocRenderer
  internal Doc? doc
  internal DefDocEnv? env
  internal DocRenderer? renderer
}

