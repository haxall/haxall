//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Jan 2021  Brian Frank  Creation
//

using concurrent
using compilerDoc

**
** DocProtoSpace is the space for all the DocProtos
**
const class DocProtoSpace : DocSpace
{
  new make(DocProto[] protos)
  {
    this.protos = protos.sort
    this.protos.each |doc| { doc.spaceRef.val = this }
  }

  override Str spaceName() { "proto" }

  const DocProtoIndex index := DocProtoIndex(this)

  const DocProto[] protos

  override Doc? doc(Str docName, Bool checked := true)
  {
    if (docName == index.docName) return index
    doc := protos.find |doc| { doc.docName == docName }
    if (doc != null) return doc
    if (checked) throw UnknownDocErr(docName)
    return null
  }

  override Void eachDoc(|Doc| f)
  {
    f(index)
    protos.each(f)
  }
}

**************************************************************************
** DocProto
**************************************************************************

**
** DocProto represents a documentation page for a single prototype
**
const class DocProto : Doc
{
  internal new make(|This| f) { f(this) }
  const Str dis
  override DocProtoSpace space() { spaceRef.val } // late bound
  internal const AtomicRef spaceRef := AtomicRef()
  override const Str docName
  override Str title() { dis }
  const DocDef[] implements
  DocProto[] children() { childrenRef.val }
  internal const AtomicRef childrenRef := AtomicRef() // late bound
  override Type renderer() { DocProtoRenderer# }
}

class DocProtoRenderer : DefDocRenderer
{
  new make(DefDocEnv env, DocOutStream out, DocProto doc) : super(env, out, doc) {}
  override Void writeContent()
  {
    proto := (DocProto)this.doc
    out.defSection("proto")
      .h1.esc(proto.dis).h1End
      .defSectionEnd
    writeListSection("implements", proto.implements)
    writeProtosSection(proto.children)
  }
}

**************************************************************************
** DocProtoIndex
**************************************************************************

const class DocProtoIndex : Doc
{
  new make(DocProtoSpace space) { this.space = space }
  override const DocProtoSpace space
  override Bool isSpaceIndex() { true }
  override Str title() { "Prototypes" }
  override Str docName() { "index" }
  override Type renderer() { DocProtoIndexRenderer# }
}

class DocProtoIndexRenderer : DefDocRenderer
{
  new make(DefDocEnv env, DocOutStream out, DocProtoIndex doc) : super(env, out, doc) {}
  override Void writeContent()
  {
    doc := (DocProtoIndex)this.doc
    protos := doc.space.protos

    out.defSection("").props
    protos.each |x| { out.propProto(x) }
    out.propsEnd.defSectionEnd
  }
}



