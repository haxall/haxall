//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

**
** DocSpec is the documentation for a Xeto spec
**
@Js
const class DocSpec : DocNode
{
  ** It-block constructor
  new make(|This| f) { f(this) }

  ** Enumerated type of this node
  override const DocNodeType nodeType
}

