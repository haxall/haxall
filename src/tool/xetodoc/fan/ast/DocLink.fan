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
  ** Constructor
  new make(Uri uri, Str dis)
  {
    this.uri = uri
    this.dis = dis
  }

  ** URI relative to base dir to page
  const Uri uri

  ** Display text for link
  const Str dis

  ** Encode to a JSON object tree
  Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered = true
    obj["uri"] = uri.toStr
    obj["dis"] = dis
    return obj
  }

  ** Decode from JSON object tree
  static DocLink? decode([Str:Obj]? obj)
  {
    if (obj == null) return null
    uri := Uri.fromStr(obj.getChecked("uri"))
    dis := obj.getChecked("dis")
    return make(uri, dis)
  }
}

