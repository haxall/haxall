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

  ** Library version
  const Version version

  ** Summary documentation for library
  const DocMarkdown doc

  ** Metadata
  const DocDict meta

  ** Dependencies
  const DocLibDepend[] depends

  ** Page type
  override DocPageType pageType() { DocPageType.lib }

  ** Title
  override Str title() { name }

  ** Library for this page (or null if top-level indexing)
  override DocLibRef? lib() { DocLibRef(name, version) }

  ** Encode to a JSON object tree
  override Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered    = true
    obj["page"]    = pageType.name
    obj["name"]    = name
    obj["version"] = version.toStr
    obj["doc"]     = doc.encode
    obj["depends"] = DocLibDepend.encodeList(depends)
    obj["meta"]    = meta.encode
    obj.addNotNull("tags",      DocTag.encodeList(tags))
    obj.addNotNull("specs",     DocSummary.encodeList(specs))
    obj.addNotNull("instances", DocSummary.encodeList(instances))
    obj.addNotNull("chapters",  DocSummary.encodeList(chapters))
    if (!readme.isEmpty) obj["readme"] = readme.encode
    return obj
  }

  ** Decode from a JSON object tree
  static DocLib doDecode(Str:Obj obj)
  {
    DocLib
    {
      it.name      = obj.getChecked("name")
      it.version   = Version.fromStr(obj.getChecked("version"))
      it.doc       = DocMarkdown.decode(obj.get("doc"))
      it.depends   = DocLibDepend.decodeList(obj["depends"])
      it.tags      = DocTag.decodeList(obj.get("tags"))
      it.meta      = DocDict.decode(obj.get("meta"))
      it.specs     = DocSummary.decodeList(obj["specs"])
      it.instances = DocSummary.decodeList(obj["instances"])
      it.chapters  = DocSummary.decodeList(obj["chapters"])
      it.readme    = DocMarkdown.decode(obj["readme"])
    }
  }

  ** Tags to annotate this summary
  const DocTag[] tags

  ** Top-level type specs defined in this library
  const DocSummary[] specs

  ** Top-level specs that types
  once DocSummary[] types() { flavor(SpecFlavor.type).toImmutable }

  ** Top-level specs that globals
  once DocSummary[] globals() { flavor(SpecFlavor.global).toImmutable }

  ** Top-level specs that meta specs
// TODO
//  once DocSummary[] metaSpecs() { flavor(SpecFlavor.meta).toImmutable }

  ** Top-level specs that funcs
  once DocSummary[] funcs() { flavor(SpecFlavor.func).toImmutable }

  ** Find top-level specs of given flavor
  DocSummary[] flavor(SpecFlavor f) { specs.findAll { it.flavor === f } }

  ** Instances defined in this library
  const DocSummary[] instances

  ** Chapters defined in this library
  const DocSummary[] chapters

  ** Readme markdown if available
  const DocMarkdown readme := DocMarkdown.empty
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
  new make(Str name, Version? version) { this.name = name; this.version = version }

  ** Library dotted name
  const Str name

  ** Version if available
  const Version? version

  ** URI to this libraries index page
  Uri uri() { DocUtil.libToUri(name) }

  ** Encode to a JSON object tree
  Obj encode()
  {
    version == null ? name : "$name-$version"
  }

  ** Decode from JSON object tree
  static DocLibRef decode(Str s)
  {
    toks := s.split('-', false)
    if (toks.size == 1)
      return make(toks[0], null)
    else
      return make(toks[0], Version.fromStr(toks[1]))
  }
}

