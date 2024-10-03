//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

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
  const DocBlock doc

  ** Metadata
  const DocDict meta

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
    obj["meta"] = meta.encode
    obj.addNotNull("types",     DocSummary.encodeList(types))
    obj.addNotNull("globals",   DocSummary.encodeList(globals))
    obj.addNotNull("instances", DocSummary.encodeList(instances))
    return obj
  }

  ** Decode from a JSON object tree
  static DocLib doDecode(Str:Obj obj)
  {
    DocLib
    {
      it.name      = obj.getChecked("name")
      it.doc       = DocBlock.decode(obj.get("doc"))
      it.meta      = DocDict.decode(obj.get("meta"))
      it.types     = DocSummary.decodeList(obj["types"])
      it.globals   = DocSummary.decodeList(obj["globals"])
      it.instances = DocSummary.decodeList(obj["instances"])
    }
  }

  ** Top-level type specs defined in this library
  const DocSummary[] types

  ** Top-level global specs defined in this library
  const DocSummary[] globals

  ** Instances defined in this library
  const DocSummary[] instances
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

