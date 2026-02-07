//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

**
** DocLink is a hyperlink
**
@Js
const class DocLink
{
  ** Empty link
  static const DocLink empty := make(``, "")

  ** Constructor
  new make(Uri uri, Str? dis)
  {
    this.uri = uri
    this.disRef = dis
  }

  ** URI relative to base dir to page
  const Uri uri

  ** Display text for link (empty string to use uri)
  Str dis() { disRef ?: uri.toStr }
  private const Str? disRef

  ** Encode to a JSON object tree
  Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered = true
    obj["uri"] = uri.toStr
    obj.addNotNull("dis", disRef)
    return obj
  }

  ** Decode from JSON object tree
  static DocLink? decode([Str:Obj]? obj)
  {
    if (obj == null) return null
    uri := Uri.fromStr(obj.getChecked("uri"))
    dis := obj.get("dis") as Str
    return make(uri, dis)
  }
}

