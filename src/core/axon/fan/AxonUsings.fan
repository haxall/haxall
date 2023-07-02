//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Mar 2023  Brian Frank  Creation
//

using xeto

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
  new make(XetoEnv env := XetoEnv.cur, Str[] qnames := ["sys"])
  {
    this.env  = env
    map := Str:AxonUsingLib[:]
    qnames.each |qname|
    {
      map[qname] = compile(qname)
    }
    this.map = map
  }

  ** Xeto environment
  const XetoEnv env

  ** List qnames configured (both ok and failures)
  Str[] qnames() { map.vals.map |u->Str| { u.qname } }

  ** List libs (qnames we loaded successfully)
  Lib[] libs()
  {
    acc := Lib[,]
    acc.capacity = acc.size
    map.each |u| { acc.addNotNull(u.lib) }
    return acc
  }

  ** Is given library qname enabled
  Bool isEnabled(Str qname) { map[qname] != null }

  ** Add new using library name
  Void add(Str qname)
  {
    if (map[qname] != null) return
    map[qname] = compile(qname)
  }

  ** Resolve simple name against imports
  Spec? resolve(Str name, Bool checked := true)
  {
    acc := Spec[,]
    map.each |u| { acc.addNotNull(u.lib?.libType(name, false)) }
    if (acc.size == 1) return acc[0]
    if (acc.size > 1) throw Err("Ambiguous types for '$name' $acc")
    if (checked) throw UnknownTypeErr(name)
    return null
  }

  ** Compile qname to AxonUsingLib
  private AxonUsingLib compile(Str qname)
  {
    try
    {
      return AxonUsingLib(qname, env.lib(qname))
    }
    catch (Err e)
    {
      echo("ERROR: Cannot compile lib '$qname'")
      return AxonUsingLib(qname, null)
    }
  }

  private Str:AxonUsingLib map
}

**************************************************************************
** AxonUsingLib
**************************************************************************

@Js
internal const class AxonUsingLib
{
  new make(Str qname, Lib? lib)
  {
    this.qname = qname
    this.lib = lib
  }

  const Str qname
  const Lib? lib
}

