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

  DocLink linkToSpec(DataSpec spec)
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

  private Void writeTypesSection(DocDataLib lib)
  {
    out.defSection("types").props
    lib.types.each |x|
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
    writeSpecMetaSection(doc.spec)
    writeSpecSlotsSection(doc)
  }

  Void writeSpecHeader(DocDataType doc)
  {
    spec := doc.spec

    out.defSection("type")
       .h1.esc(spec.name).h1End

    if (spec.base != null)
    {
      out.p("class='docgen-type-sig'").code
      out.w(spec.name).w(": ")
      writeSpecBase(spec)
      out.codeEnd.pEnd
    }

    out.fandoc(doc.docFull)
       .defSectionEnd
  }

  private Void writeSpecBase(DataType spec)
  {
    if (spec.isCompound) return writeSpecBaseCompound(spec.ofs, spec.isAnd ? "&" : "|")
    out.linkTo(linkToSpec(spec.base))
    if (spec.isMaybe) out.w("?")
  }

  private Void writeSpecBaseCompound(DataSpec[] ofs, Str sep)
  {
    ofs.each |of, i|
    {
      if (i > 0) out.w(" ").esc(sep).w(" ")
      out.linkTo(linkToSpec(of))
    }
  }

  Void writeSpecSlotsSection(DocDataType doc)
  {
    out.defSection(doc.spec.isLib ? "types" : "slots").props
    doc.spec.slots.each |slot|
    {
      out.prop(slot.name, "")
    }
    out.propsEnd.defSectionEnd
  }
}