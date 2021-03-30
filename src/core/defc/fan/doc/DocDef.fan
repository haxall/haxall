//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Jun 2018  Brian Frank  Creation
//

using concurrent
using compilerDoc
using web
using haystack
using def

**
** DocDef represents a documentation page for a single definition
**
const class DocDef : Doc
{
  internal new make(DocLib lib, CLoc loc, Def def)
  {
    this.lib        = lib
    this.loc        = loc
    this.def        = def
    this.docNameRef = def.symbol.toStr.replace(":", "~")
    this.docFull    = CFandoc(loc, def["doc"] ?: "")
    this.docSummary = docFull.toSummary
  }

  const DocLib lib

  const CLoc loc

  const Def def

  Str name() { def.name }

  Str dis() { toStr }

  Symbol symbol() { def.symbol }

  SymbolType type() { def.symbol.type }

  Bool has(Str name) { def.has(name) }

  Bool missing(Str name) { def.missing(name) }

  override Str docName() { docNameRef }
  private const Str docNameRef

  override DocSpace space() { lib }

  override Bool isCode() { true }

  const CFandoc docSummary

  const CFandoc docFull

  override Str breadcrumb() { title }

  override Str title() { dis }

  Str? subtitle() { subtitleRef.val }
  const AtomicRef subtitleRef := AtomicRef()

  override Type renderer() { rendererRef.val }
  const AtomicRef rendererRef := AtomicRef(StdDocDefRenderer#)

  override Str toStr() { def.symbol.toStr }

  override Int compare(Obj that) { toStr <=> that.toStr }

  DocProto[] children() { childrenRef.val }
  internal const AtomicRef childrenRef := AtomicRef() // late bound
}

**************************************************************************
** StdDefRenderer
**************************************************************************

**
** StdDocDefRenderer
**
class StdDocDefRenderer : DefDocRenderer
{
  new make(DocEnv env, WebOutStream out, DocDef doc) : super(env, out, doc) {}

  override DocDef doc() { super.doc }

  override Void writeContent()
  {
    writeDefHeader("def", doc.symbol.toStr, doc.subtitle, doc.docFull)
    writeConjunct
    writeMetaSection(doc.def)
    writeUsageSection
    writeEnumSection
    writeTreeSection("supertypes", env.supertypeTree(doc))
    writeTreeSection("subtypes",   env.subtypeTree(doc))
    writeAssociationSections
    writeProtosSection(doc.children)
  }

  virtual Void writeConjunct()
  {
    if (!doc.type.isConjunct) return
    out.defSection("conjunct").props
    doc.symbol.eachPart |tagName|
    {
      tag := env.def(tagName, false)
      if (tag == null) out.esc(tagName)
      else out.propDef(tag)
    }
    out.propsEnd.defSectionEnd
  }

  virtual Void writeUsageSection()
  {
    usage := env.ns.implement(doc.def)
    if (usage.size <= 1) return
    out.defSection("usage").props.tr.th
    usage.each |u, i| { if (i > 0) out.w("&nbsp;&nbsp;"); out.linkDef(u) }
    out.thEnd.trEnd.propsEnd.defSectionEnd
  }

  virtual Void writeEnumSection()
  {
    enumVal := doc.def["enum"]
    if (enumVal == null) return

    enum := DefUtil.parseEnum(enumVal)
    out.defSection("enum").props
    enum.each |dict, name|
    {
      enumDoc := dict["doc"] ?: ""
      out.prop(name, CFandoc(doc.loc, enumDoc))
    }
    out.propsEnd.defSectionEnd
  }

  virtual Void writeTreeSection(Str name, DocDefTree tree)
  {
    if (tree.isEmpty) return
    out.defSection(name).props
    tree.each |indent, term| { out.propDef(term, term.dis, indent) }
    out.propsEnd.defSectionEnd
  }

  virtual Void writeAssociationSections()
  {
    env.docAssociations.each |assoc|
    {
      writeListSection(assoc.name, env.associations(doc, assoc))
    }
  }

}

