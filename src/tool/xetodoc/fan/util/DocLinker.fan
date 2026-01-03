//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Jan 2026  Brian Frank  Creation
//

using markdown
using util
using xeto

**
** DocLinker is use to resolve shortcut links against current location
**
const class DocLinker
{
  ** Constructor with given location
  new make(Namespace ns, Lib? lib, Spec? spec := null)
  {
    this.ns       = ns
    this.lib      = lib
    this.spec     = spec
  }

  ** Resolve destination against current location or null if unresolved
  Str? resolve(Str dest)
  {
    null
  }

  ** File location based on current lib/spec location
  FileLoc loc()
  {
    if (spec != null) return spec.loc
    if (lib != null) return lib.loc
    return FileLoc.unknown
  }

  const Namespace ns
  const Lib? lib
  const Spec? spec
}

