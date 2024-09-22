//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using haystack

**
** DocDict is base class for dict values: meta, instances, and nested dict values
**
/*
@Js
abstract const class DocDict : DocNodeObj
{
  ** Constructor
  new make(Str:Obj obj)
  {
    this.obj      = obj
    this.nodeType = obj.getChecked("_node")
  }

  ** Node object name/value pairs
  override const Str:Obj obj

  ** Enumerated type of this node
  override const DocNodeType nodeType

  ** Get value
  Obj? get(Str name) { obj.get(name) }
}
*/

