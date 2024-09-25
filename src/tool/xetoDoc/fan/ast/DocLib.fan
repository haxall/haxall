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
  const override Uri uri

  ** Dotted name for library
  const Str name

  ** Summary documentation for library
  const DocBlock doc

  ** Metadata
  const DocDict meta

  ** Page type
  override DocPageType pageType() { DocPageType.lib }

  ** Encode to a JSON object tree
  override Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered = true
    obj["page"] = pageType.name
    obj["uri"]  = uri.toStr
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
      it.uri       = Uri.fromStr(obj.getChecked("uri"))
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

