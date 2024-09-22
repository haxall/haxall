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

  ** Node type
//   override DocNodeType nodeType() { DocNodeType.summary }

  ** Title and hyperlink
  const DocLink link

  ** Formatted summary text
  const DocBlock text

  ** Debug string
  override Str toStr() { "$link.dis: $text" }

  ** Get this node as a map of name/value pairs
  Str:Obj encode()
  {
    obj := Str:Obj[:]
    obj.ordered = true
    obj["link"] = link
    obj["text"] = text
    return obj
  }

}

