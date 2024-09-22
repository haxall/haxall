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
const class DocSummary : DocNode
{
  ** Constructor
  new make(DocLink link, DocBlock text)
  {
    this.link = link
    this.text = text
  }

  ** Node type
  override DocNodeType nodeType() { DocNodeType.summary }

  ** Title and hyperlink
  const DocLink link

  ** Formatted summary text
  const DocBlock text

  ** Debug string
  override Str toStr() { "$link.dis: $text" }
}

