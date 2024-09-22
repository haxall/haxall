//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

**
** DocNode is base class for AST nodes
**
@Js
abstract const class DocNode
{
  ** Enumerated type of this node
  abstract DocNodeType nodeType()

}

**************************************************************************
** DocNodeType
**************************************************************************

**
** DocNode enumerated type
**
@Js
enum class DocNodeType
{
  nodeList,
  lib,
  libMeta,
  type,
  global,
  instance,
  summary,
  block,
  link,
  scalar
}

