//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Jun 2018  Brian Frank  Creation
//

using haystack
using concurrent
using compilerDoc
using web

const class DocAppendixSpace : DocSpace
{
  new make(DocAppendix[] docs)
  {
    this.docs = docs.sort
    this.docsMap = Str:Doc[:].addList(docs) { it.docName }
    this.docs.each |doc| { doc.spaceRef.val = this }
  }

  override Str spaceName() { "appendix" }

  const DocAppendix[] docs

  override Doc? doc(Str docName, Bool checked := true)
  {
    doc := docsMap[docName]
    if (doc != null) return doc
    if (checked) throw UnknownDocErr(docName)
    return null
  }
  private const Str:DocAppendix docsMap

  override Void eachDoc(|Doc| f) { docs.each(f) }
}

**************************************************************************
** DocAppendix (base class for documents)
**************************************************************************

abstract const class DocAppendix : Doc
{
  override DocAppendixSpace space() { spaceRef.val } // late bound
  internal const AtomicRef spaceRef := AtomicRef()
  override Str title() { docName }
  abstract Str group()
  abstract Obj summary()
}

**************************************************************************
** DocAppendixIndex
**************************************************************************

const class DocAppendixIndex : DocAppendix
{
  override Bool isSpaceIndex() { true }
  override Str title() { "Appendix" }
  override Str summary() { "Index of all appendex documents" }
  override Str docName() { "index" }
  override Str group() { "index" }
  override Type renderer() { DocAppendixIndexRenderer# }
}

class DocAppendixIndexRenderer : DefDocRenderer
{
  new make(DefDocEnv env, DocOutStream out, DocAppendixIndex doc) : super(env, out, doc) {}
  override Void writeContent() { doWriteContent(out, doc.space) }
  static Void doWriteContent(DocOutStream out, DocAppendixSpace space)
  {
    out.trackToNavData = true

    docs := space.docs

    groups := Str[,]
    docs.each |x| { if (!groups.contains(x.group)) groups.add(x.group) }
    groups.remove("index")
    groups.moveTo("quick", 0)

    groups.each |group|
    {
      out.defSection(group).props
      docs.each |x| { if (x.group == group) out.prop(x, x.summary) }
      out.propsEnd.defSectionEnd
    }
  }
}

**************************************************************************
** DocTaxonomyAppendix
**************************************************************************

const class DocTaxonomyAppendix : DocAppendix
{
  new make(DocDef def) { this.def = def}
  const DocDef def
  override Str docName() { def.docName }
  override Type renderer() { DocTaxonomyAppendixRenderer# }
  override Str group() { "taxonomies" }
  override Obj summary() { def.docSummary }
}

class DocTaxonomyAppendixRenderer : DefDocRenderer
{
  new make(DefDocEnv env, DocOutStream out, DocTaxonomyAppendix doc) : super(env, out, doc) {}
  override Void writeContent()
  {
    out.trackToNavData = true
    env := (DefDocEnv)this.env
    doc := (DocTaxonomyAppendix)this.doc
    def := doc.def
    out.defSection("")
       .props
       .propDef(def, def.dis, 0)
    tree := env.subtypeTree(def)
    tree.each |indent, term| { out.propDef(term, term.dis, indent+1) }
    out.propsEnd.defSectionEnd
  }
}

**************************************************************************
** DocListAppendix
**************************************************************************

abstract const class DocListAppendix : DocAppendix
{
  override Str group() { "listings" }
  override Type renderer() { DocListAppendixRenderer# }
  abstract Bool include(DocDef d)
  virtual DocDef[] collect(DefDocEnv env) { env.findDefs |d| { include(d) } }
}

class DocListAppendixRenderer : DefDocRenderer
{
  new make(DefDocEnv env, DocOutStream out, DocListAppendix doc) : super(env, out, doc) {}
  override Void writeContent()
  {
    out.trackToNavData = true
    doc := (DocListAppendix)this.doc
    list := doc.collect(env)
    out.defSection("")
       .fandoc(CFandoc(CLoc.none, doc.summary))
       .props
    list.each |def| { out.propDef(def, def.name) }
    out.propsEnd.defSectionEnd
  }
}

**************************************************************************
** DocListAppendix subclasses
**************************************************************************

internal const class DocTagAppendix : DocListAppendix
{
  override Str docName() { "tags" }
  override Bool include(DocDef def) { def.type.isTag }
  override Str summary() { "All tags listed alphabetically" }
}

internal const class DocConjunctAppendix : DocListAppendix
{
  override Str docName() { "conjuncts" }
  override Bool include(DocDef def) { def.type.isConjunct }
  override Str summary() { "All tag conjuncts listed alphabetically" }
}

internal const class DocLibAppendix : DocListAppendix
{
  override Str docName() { "libs" }
  override Str summary() { "All libs listed alphabetically" }
  override Bool include(DocDef d) { throw UnsupportedErr() }
  override DocDef[] collect(DefDocEnv env) { env.libs.map |lib->DocDef| { lib.index } }
}

internal const class DocFeatureAppendix : DocListAppendix
{
  new make(DocDef f) { feature = f; this.docName = f.name + "s" }
  const DocDef feature
  const override Str docName
  override Bool include(DocDef def) { def.type.isKey && def.symbol.part(0) == feature.name }
  override Str summary() { "All $docName listed alphabetically" }
}