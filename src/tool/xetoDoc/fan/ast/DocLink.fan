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
const class DocLink : DocNode
{
  ** Constructor
  new make(DocId href, Str dis := href.dis)
  {
    this.href = href
    this.dis  = dis
  }

  ** Node type
  override DocNodeType nodeType() { DocNodeType.link }

  ** Doc identifier to link to
  const DocId href

  ** Display text
  const Str dis
}

