//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using xeto

**
** DocSummary is a hyperlink to a node with a formatted summary sentence.
**
@Js
const class DocSummary
{
  ** Constructor
  new make(DocLink link, DocMarkdown text, DocTag[]? tags := null, DocTypeRef? type := null)
  {
    this.link   = link
    this.text   = text
    this.tags   = tags ?: DocTag.emptyList
    this.flavor = DocTags.toFlavor(this.tags.first)
    this.type   = type
  }

  ** Title and hyperlink
  const DocLink link

  ** Formatted summary text
  const DocMarkdown text

  ** Tags to annotate this summary
  const DocTag[] tags

  ** Optional type ref used for some summaries (such as globals)
  const DocTypeRef? type

  ** If associated with a flavor
  const SpecFlavor? flavor

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
    obj.addNotNull("tags", DocTag.encodeList(tags))
    obj.addNotNull("type", type?.encode)
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
    text := DocMarkdown.decode(obj.getChecked("text"))
    tags := DocTag.decodeList(obj.get("tags"))
    type := DocTypeRef.decode(obj.get("type"))
    return make(link, text, tags, type)
  }

}

