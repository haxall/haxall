//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jan 2021  Brian Frank  Creation
//

using fandoc
using compilerDoc
using haystack
using def

**
** Generate the DefDocEnv which models the doc spaces and documents
**
internal class GenDocEnv : DefCompilerStep
{
  new make(DefCompiler c) : super(c) {}

  override Void run()
  {
    compiler.index.libs.each |lib|
    {
      if (includeLib(lib)) addSpace(genLib(lib))
    }
    addSpace(genProtos)
    addSpace(genAppendix)
    compiler.manuals.each |manual| { addSpace(manual) }
    compiler.docEnv = DefDocEnv(ns, spacesMap, defsMap)
  }

  private DocLib genLib(CLib lib)
  {
    DocLib
    {
      it.name       = lib.name
      it.def        = lib.actual(compiler.ns)
      it.index      = DocLibIndex(it)
      it.defs       = genDefs(it, lib.defs.vals).sort
      it.docFull    = CFandoc(lib.loc, it.def["doc"] as Str ?: "")
      it.docSummary = docFull.toSummary
    }
  }

  private DocDef[] genDefs(DocLib lib, CDef[] defs)
  {
    defs = defs.findAll |def| { includeDef(def) }
    return defs.map |def->DocDef|
    {
      def.doc = addDefDoc(genDef(lib, def))
    }
  }

  private DocDef genDef(DocLib lib, CDef def)
  {
    DocDef(lib, def.loc, def.actual(compiler.ns))
  }

  private DocProtoSpace genProtos()
  {
    // map mutable CProtos to immutable DocProto
    acc := index.protos.map |c->DocProto|
    {
      c.doc = DocProto
      {
        it.dis        = c.dis
        it.docName    = c.docName
        it.implements = mapDefs(c.implements)
      }
    }

    // backpatch children on DocProto
    index.protos.each |c|
    {
      c.doc.childrenRef.val = mapProtos(c.children)
    }

    // backpatch children on DocDef
    index.defs.each |c|
    {
      if (c.doc != null) c.doc.childrenRef.val = mapProtos(c.children)
    }

    return DocProtoSpace(acc)
  }

  private DocDef[] mapDefs(CDef[] list)
  {
    if (list.isEmpty) return DocDef#.emptyList
    return list.map |x->DocDef?| { x.doc }.findNotNull.toImmutable
  }

  private DocProto[] mapProtos(CProto[]? list)
  {
    if (list == null || list.isEmpty) return DocProto#.emptyList
    return list.map |x->DocProto| { x.doc }.toImmutable
  }

  private DocAppendixSpace genAppendix()
  {
    acc := DocAppendix[,]

    // index
    acc.add(DocAppendixIndex())

    // special listings
    acc.add(DocTagAppendix())
    acc.add(DocConjunctAppendix())
    acc.add(DocLibAppendix())

    // feature listings
    compiler.ns.features.each |f|
    {
      if (f.name == "lib") return
      doc := defsMap[f.name]
      if (doc != null) acc.add(DocFeatureAppendix(doc))
    }

    // taxonomies
    defsMap.each |def|
    {
      if (def.has("docTaxonomy")) acc.add(DocTaxonomyAppendix(def))
    }

    return DocAppendixSpace(acc)
  }

  private Bool includeLib(CLib lib)
  {
    compiler.includeInDocs(lib)
  }

  private Bool includeDef(CDef def)
  {
    compiler.includeInDocs(def)  && !def.isLib
  }

  private Void addSpace(DocSpace space)
  {
    spacesMap.add(space.spaceName, space)
  }

  private DocDef addDefDoc(DocDef def)
  {
    defsMap.add(def.symbol.toStr, def)
    return def
  }

  private Str:DocSpace spacesMap := [:]
  private Str:DocDef defsMap := [:]
}