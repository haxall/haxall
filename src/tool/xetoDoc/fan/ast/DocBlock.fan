//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

**
** DocBlock is a formatted block of text.
**
@Js
const class DocBlock : DocNode
{
  ** Empty string
  static const DocBlock empty := make("")

  ** Constructor
  new make(Str text) { this.text = text }

  ** Node type
  override DocNodeType nodeType() { DocNodeType.block }

  ** TODO: just wrap plain text string for now
  const Str text

  ** Debug string
  override Str toStr() { text }

  ** Encode to a JSON object tree
  Obj encode()
  {
    text
  }

  ** Decode from JSON object tree
  static DocBlock decode(Obj? obj)
  {
    if (obj == null) return empty
    return DocBlock(obj.toStr)
  }
}

