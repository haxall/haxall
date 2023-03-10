//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Mar 2023  Brian Frank  Creation
//

using data

**
** AxonUsings manages the data spec namespace for a top-level function frame:
**   - using imports
**   - resolving type names
**   - function local spec definitions
**
@NoDoc @Js
class AxonUsings
{
  ** Constructor
  new make()
  {
    this.data = DataEnv.cur
    this.libs = [data.sysLib]
  }

  ** Data environment
  const DataEnv data

  ** List libraries we are using
  DataLib[] list()
  {
    libs.dup
  }

  ** Add new using library name
  Void add(Str qname)
  {
    lib := data.lib(qname)
    if (libs.containsSame(lib)) return
    libs.add(lib)
  }

  ** Resolve simple name against imports
  DataSpec? resolve(Str name, Bool checked := true)
  {
    acc := DataSpec[,]
    libs.each |lib| { acc.addNotNull(lib.slotOwn(name, false)) }
    if (acc.size == 1) return acc[0]
    if (acc.size > 1) throw Err("Ambiguous types for '$name' $acc")
    if (checked) throw UnknownTypeErr(name)
    return null
  }

  private DataLib[] libs
}