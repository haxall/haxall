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
  new make(DataEnv env := DataEnv.cur, [Str:DataLib]? libs := null)
  {
    this.env  = env
    this.libs = libs ?: ["sys":env.sysLib]
  }

  ** Data environment
  const DataEnv env

  ** List libraries we are using
  DataLib[] list() { libs.vals }

  ** Is given library qname enabled
  Bool isEnabled(Str qname) { libs[qname] != null }

  ** Add new using library name
  Void add(Str qname)
  {
    if (libs[qname] != null) return
    lib := env.lib(qname)
    libs.add(qname, lib)
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

  private Str:DataLib libs
}