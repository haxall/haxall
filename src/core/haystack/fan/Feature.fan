//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Jan 2019  Brian Frank  Creation
//

**
** Feature defines an application specific namespace of defs
** such as filetype, lib, and func.
**
@NoDoc @Js
const mixin Feature
{

  ** Return name of the feature
  abstract Str name()

  ** Return the def of feature itself
  abstract Def self()

  ** Resolve a definition by name within this feature namespace
  abstract Def? def(Str name, Bool checked := true)

  ** Build a list of all defs within this feature.  This call
  ** can be expensive so prefer `eachDef` or `findDefs`.
  @NoDoc abstract Def[] defs()

  ** Iterate all the definitions within this feature namespace
  @NoDoc abstract Void eachDef(|Def| f)

  ** Find all defs which match given predicate function
  @NoDoc abstract Def[] findDefs(|Def->Bool| f)

  ** Flatten all defs in this feature to a single sorted grid
  @NoDoc abstract Grid toGrid()

}