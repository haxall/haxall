//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Apr 2023  Brian Frank  Creation
//

using compilerDoc
using data
using haystack

**
** DocDataLib is the space for a DataLib
**
const class DocDataLib : DocSpace
{
  internal new make(|This| f) { f(this) }

  const DataLib spec

  const Str qname

  override Str spaceName() { "spec-$qname" }

  override Str breadcrumb() { qname }

  const DocDataLibIndex index

  const DocDataType[] types

  const CFandoc docSummary

  const CFandoc docFull

  override Doc? doc(Str docName, Bool checked := true)
  {
    if (docName == index.docName) return index
    doc := types.find |doc| { doc.docName == docName }
    if (doc != null) return doc
    if (checked) throw UnknownDocErr(docName)
    return null
  }

  override Void eachDoc(|Doc| f)
  {
    f(index)
    types.each(f)
  }
}

**************************************************************************
** DocDataLibIndex
**************************************************************************

const class DocDataLibIndex : Doc
{
  new make(DocDataLib lib) { this.lib = lib }
  const DocDataLib lib

  override DocSpace space() { lib }

  override Str docName() { "index" }

  override Str title() { lib.qname }

  override Bool isSpaceIndex() { true }

  override Type renderer() { DocDataLibIndexRenderer# }
}

**************************************************************************
** DocDataType
**************************************************************************

**
** DocDataType is a documentation page for a DataType
**
const class DocDataType : Doc
{
  internal new make(DocDataLib lib, DataType spec, CFandoc docFull)
  {
    this.lib        = lib
    this.spec       = spec
    this.name       = spec.name
    this.docFull    = docFull
    this.docSummary = docFull.toSummary
  }

  const DocDataLib lib

  const DataType spec

  const Str name

  const CFandoc docSummary

  const CFandoc docFull

  override DocSpace space() { lib }

  override Str docName() { name }

  override Str title() { spec.qname }

  override Type renderer() { DataTypeDocRenderer# }
}

**************************************************************************
** DocDataSpecRenderer
**************************************************************************

abstract class DocDataSpecRenderer : DefDocRenderer
{
  new make(DefDocEnv env, DocOutStream out, Doc doc) : super(env, out, doc) {}

  DocLink specToLink(DataSpec spec)
  {
    Doc? to := null
    Str dis := spec.name

    if (spec.isLib)
    {
      to = env.space("spec-$spec.qname", false)?.doc("index", false)
      dis = spec.qname
    }
    else
    {
      type := spec.type
      to = env.space("spec-$type.lib.qname", false)?.doc(type.name, false)
    }

    if (to == null)
    {
      echo("WARN: Unresolved spec link: $spec.qname")
      to = env.space("spec-sys").doc("index")
    }

    return DocLink(this.doc, to, dis)
  }
}

**************************************************************************
** DocDataLibIndexRenderer
**************************************************************************

class DocDataLibIndexRenderer : DocDataSpecRenderer
{
  new make(DefDocEnv env, DocOutStream out, DocDataLibIndex doc) : super(env, out, doc) {}

  override Void writeContent()
  {
    doc := (DocDataLibIndex)this.doc
    lib := doc.lib

    writeDefHeader("lib", lib.qname, null, lib.docFull)
    writeSpecMetaSection(lib.spec)
    writeTypesSection(lib)
  }

  Void writeSpecMetaSection(DataSpec spec)
  {
    names := Etc.dictNames((Dict)spec)
    names.remove("doc")
    names.remove("ofs")
    if (names.isEmpty) return

    out.defSection("meta").props
    names.sort.each |name|
    {
      val := spec[name]

      // specific tags handled specially
      switch (name)
      {
        case "depends": val = toDependLinks(val)
      }

      // show dict as foo.bar props
      if (val is Dict)
      {
        ((Dict)val).each |v, n| { out.prop(name + "." + n, v) }
        return
      }

      out.prop(name, val)
    }
    out.propsEnd.defSectionEnd
  }

  private Obj[] toDependLinks(Obj val)
  {
    acc := Obj[,]
    ((Dict)val).each |Dict v|  // xeto compiler should reify as list
    {
      qname := v["lib"]
      item := qname
      lib := env.space("spec-$qname", false)?.doc("index", false)
      if (lib != null) item = DocLink(doc, lib, qname)
      acc.add(item)
    }
    return acc
  }

  private Void writeTypesSection(DocDataLib lib)
  {
    out.defSection("types").props
    types := lib.types.dup.sort |a, b| { a.name <=> b.name }
    types.each |x|
    {
      out.prop(DocLink(doc, x, x.name), x.docSummary)
    }
    out.propsEnd.defSectionEnd
  }
}

**************************************************************************
** DataTypeDocRenderer
**************************************************************************

class DataTypeDocRenderer : DocDataSpecRenderer
{
  new make(DefDocEnv env, DocOutStream out, DocDataType doc) : super(env, out, doc) {}

  override Void writeContent()
  {
    doc := (DocDataType)this.doc
    writeSpecHeader(doc)
    writeSlotsIndexSection(doc)
    writeSlotsDetailSection(doc)
  }

  Void writeSpecHeader(DocDataType doc)
  {
    spec := doc.spec

    out.defSection("type")
       .h1.esc(spec.name).h1End

    if (spec.base != null) writeSpecSig(spec, true)

    out.fandoc(doc.docFull)
       .defSectionEnd
  }

  private Void writeSlotsIndexSection(DocDataType doc)
  {
    if (doc.spec.slots.isEmpty) return
    out.defSection(doc.spec.isLib ? "types" : "slots").props
    doc.spec.slots.each |slot|
    {
      out.prop(DocLink(doc, doc, slot.name, slot.name), specDoc(slot).toSummary)
    }
    out.propsEnd.defSectionEnd
  }

  private Void writeSlotsDetailSection(DocDataType doc)
  {
    if (doc.spec.slots.isEmpty) return
    out.defSection("").h2("class='defc-slot-details' id='slot-details'").w("Slot Details").h2End.defSectionEnd
    doc.spec.slots.each |slot|
    {
      writeSlotDetailSection(slot)
    }
  }

  private Void writeSlotDetailSection(DataSpec slot)
  {
    // each slot is one section
    out.defSection(slot.name).div("class='defc-type-slot-section'")

    // signature line with meta
    writeSpecSig(slot, false)

    // fandoc
    out.fandoc(specDoc(slot))

    // query
    writeConstrainedQuery(slot)

    // end section
    out.divEnd.defSectionEnd
  }

  private Void writeConstrainedQuery(DataSpec slot)
  {
    if (!slot.isQuery || slot.slots.isEmpty) return

    out.p.w("Required $slot.name:").pEnd
    out.ul
    slot.slots.each |item|
    {
      out.li
      writeConstrainedQueryItem(item)
      out.liEnd
    }
    out.ulEnd
  }

  private Void writeConstrainedQueryItem(DataSpec spec)
  {
    out.span("class='defc-type-sig'")
    out.linkTo(specToLink(spec.base))
    if (spec.isMaybe) out.w("?")
    if (!spec.slotsOwn.isEmpty)
    {
      out.w(" {")
      first := true
      spec.slotsOwn.each |tag|
      {
        if (first) first = false; else out.w(", ")
        n := tag.name
        def := env.def(n, false)
        if (def != null) out.link(def)
        else out.w(tag.name)
      }
      out.w(" }")
    }
    out.spanEnd
    out.w("&nbsp;&nbsp;&nbsp;").w(specDoc(spec).summary)
  }

//////////////////////////////////////////////////////////////////////////
// Spec Signature
//////////////////////////////////////////////////////////////////////////

  private Void writeSpecSig(DataSpec spec, Bool withName)
  {
    out.p("class='defc-type-sig'").code
    if (withName) out.w(spec.name).w(": ")
    writeSpecBase(spec)
    writeSpecMeta(spec)
    writeSpecVal(spec)
    out.codeEnd.pEnd
  }

  private Void writeSpecBase(DataSpec spec)
  {
    if (spec.isCompound) return writeSpecBaseCompound(spec.ofs, spec.isAnd ? "&" : "|")
    out.linkTo(specToLink(spec.base))
    if (spec.isMaybe) out.w("?")
  }

  private Void writeSpecBaseCompound(DataSpec[] ofs, Str sep)
  {
    ofs.each |of, i|
    {
      if (i > 0) out.w(" ").esc(sep).w(" ")
      out.linkTo(specToLink(of))
    }
  }

  private Void writeSpecMeta(DataSpec spec)
  {
    names := Str[,]
    spec.each |v, n|
    {
      if (n == "doc") return
      if (n == "val") return
      if (n == "maybe") return
      if (n == "ofs" && spec.isCompound) return
      names.add(n)
    }
    if (names.isEmpty) return
    out.esc(" <")
    names.each |n, i|
    {
      if (i > 0) out.w(", ")
      v := spec[n]
      out.w(n)
      if (v === Marker.val) return
      out.w(":")
      if (v is DataSpec)
        out.linkTo(specToLink(v))
      else
        out.esc(v.toStr.toCode)
    }
    out.esc(">")
  }

  private Void writeSpecVal(DataSpec spec)
  {
    val := spec["val"]
    if (val == null || val == Marker.val) return
    out.w(" ").esc(val.toStr.toCode)
  }

//////////////////////////////////////////////////////////////////////////
// Spec Doc
//////////////////////////////////////////////////////////////////////////

  private CFandoc specDoc(DataSpec spec)
  {
    d := slotDocs[spec.qname]
    if (d == null) slotDocs[spec.qname] = d = resolveSpecDoc(spec)
    return d
  }

  private CFandoc resolveSpecDoc(DataSpec spec)
  {
    if (spec.isMarker)
    {
      tag := env.def(spec.name, false)
      if (tag != null) return tag.docFull
    }

    return CFandoc(CLoc(spec.loc), spec["doc"] ?: "")
  }

  private Str:CFandoc slotDocs := [:]
}