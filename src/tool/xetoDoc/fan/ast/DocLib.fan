//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using haystack

**
** DocLib is the documentation for a Xeto library
**
@Js
const class DocLib : DocNode
{
  ** It-block constructor
  new make(|This| f) { f(this) }

  ** Identifier for this library
  const DocId id

  ** Enumerated type of this node
  override DocNodeType nodeType() { DocNodeType.lib }

  ** Unique library dotted name
  const Str name

  ** Library metadata
  const DocLibMeta meta

  ** Top-level type spesc defined in this library
  const DocSummary[] types

  ** Top-level global specs contained in this library
  const DocSummary[] globals

  ** Instances defined in this library
  const DocSummary[] instances
}

**************************************************************************
** DocLibMeta
**************************************************************************

**
** Library metadata
**
@Js
const class DocLibMeta : DocDict
{
  ** It-block constructor
  new make(Dict dict) : super(dict) {}

  ** Enumerated type of this node
  override DocNodeType nodeType() { DocNodeType.libMeta }
}

