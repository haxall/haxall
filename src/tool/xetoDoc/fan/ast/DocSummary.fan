//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

**
** DocSummary is a hyperlink to a node with a formatted summary sentence.
**
@Js
const class DocSummary
{
  ** Constructor
  new make(DocLink link, DocBlock text)
  {
    this.link = link
    this.text = text
  }

  ** Title and hyperlink
  const DocLink link

  ** Formatted summary text
  const DocBlock text

  ** Debug string
  override Str toStr() { "$link.dis: $text" }

  ** Encode a list or null if empty
  static Obj? encodeList(DocSummary[] list)
  {
    if (list.isEmpty) return null
    return list.map |x->Str:Obj| { x.encode }
  }

  ** Encode to a JSON object tree
  Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered = true
    obj["link"] = link.encode
    obj["text"] = text.encode
    return obj
  }

  ** Decode a list or empty if null
  static DocSummary[] decodeList(Obj[]? list)
  {
    if (list == null || list.isEmpty) return DocSummary#.emptyList
    return list.map |x->DocSummary| { decode(x) }
  }

  ** Decode from JSON object tree
  static DocSummary decode(Str:Obj obj)
  {
    link := DocLink.decode(obj.getChecked("link"))
    text := DocBlock.decode(obj.getChecked("text"))
    return make(link, text)
  }

}

