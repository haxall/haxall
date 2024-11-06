//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using xeto
using haystack

**
** DocLib is the documentation page for a Xeto library
**
@Js
const class DocLib : DocPage
{
  ** Constructor
  new make(|This| f) { f(this) }

  ** URI relative to base dir to page
  override Uri uri() { DocUtil.libToUri(name) }

  ** Dotted name for library
  const Str name

  ** Summary documentation for library
  const DocMarkdown doc

  ** Metadata
  const DocDict meta

  ** Dependencies
  const DocLibDepend[] depends

  ** Page type
  override DocPageType pageType() { DocPageType.lib }

  ** Library for this page (or null if top-level indexing)
  override DocLibRef? lib() { DocLibRef(name) }

  ** Encode to a JSON object tree
  override Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered = true
    obj["page"] = pageType.name
    obj["name"] = name
    obj["doc"]  = doc.encode
    obj["depends"] = DocLibDepend.encodeList(depends)
    obj["meta"] = meta.encode
    obj.addNotNull("types",     DocSummary.encodeList(types))
    obj.addNotNull("globals",   DocSummary.encodeList(globals))
    obj.addNotNull("instances", DocSummary.encodeList(instances))
    obj.addNotNull("chapters",  DocSummary.encodeList(chapters))
    return obj
  }

  ** Decode from a JSON object tree
  static DocLib doDecode(Str:Obj obj)
  {
    DocLib
    {
      it.name      = obj.getChecked("name")
      it.doc       = DocMarkdown.decode(obj.get("doc"))
      it.depends   = DocLibDepend.decodeList(obj["depends"])
      it.meta      = DocDict.decode(obj.get("meta"))
      it.types     = DocSummary.decodeList(obj["types"])
      it.globals   = DocSummary.decodeList(obj["globals"])
      it.instances = DocSummary.decodeList(obj["instances"])
      it.chapters  = DocSummary.decodeList(obj["chapters"])
    }
  }

  ** Top-level type specs defined in this library
  const DocSummary[] types

  ** Top-level global specs defined in this library
  const DocSummary[] globals

  ** Instances defined in this library
  const DocSummary[] instances

  ** Chapters defined in this library
  const DocSummary[] chapters
}

**************************************************************************
** DocLibDepend
**************************************************************************

@Js
const class DocLibDepend
{
  ** Constructor
  new make(DocLibRef lib, LibDependVersions versions)
  {
    this.lib      = lib
    this.versions = versions
  }

  ** Library
  const DocLibRef lib

  ** Dependency version requirements
  const LibDependVersions versions

  ** Decode list
  static Obj[] encodeList(DocLibDepend[] list)
  {
    list.map |x| { x.encode }
  }

  ** Encode to a JSON object tree
  Str:Obj encode()
  {
    acc := Str:Obj[:]
    acc.ordered = true
    acc["lib"] = lib.encode
    acc["versions"] = versions.toStr
    return acc
  }

  ** Decode list
  static DocLibDepend[] decodeList(Obj[]? list)
  {
    if (list == null) return DocLibDepend#.emptyList
    return list.map |x| { decode(x) }
  }

  ** Decode from JSON object tree
  static DocLibDepend decode(Str:Obj obj)
  {
    lib := DocLibRef.decode(obj.getChecked("lib"))
    versions := LibDependVersions.fromStr(obj.getChecked("versions"))
    return make(lib, versions)
  }
}

**************************************************************************
** DocLibRef
**************************************************************************

@Js
const class DocLibRef
{
  ** Constructor
  new make(Str name) { this.name = name }

  ** Library dotted name
  const Str name

  ** URI to this libraries index page
  Uri uri() { DocUtil.libToUri(name) }

  ** Encode to a JSON object tree
  Obj encode()
  {
    name
  }

  ** Decode from JSON object tree
  static DocLibRef decode(Str s)
  {
    make(s)
  }
}

