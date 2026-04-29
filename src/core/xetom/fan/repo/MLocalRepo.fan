//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Apr 2026  Brian Frank  Creation
//

using xeto
using haystack

**
** MLocalRepo is based class for all LocalRepo implementations
**
@Js
abstract const class MLocalRepo : MRepo, LocalRepo
{
  new make(XetoEnv env) : super(env) {}

  override final Bool isLocal() { true }

  override final Bool isRemote() { false }

  override final Str name() { "local" }

  override final Uri uri() { `local:` }

  override Dict meta() { Etc.dict0 }

  override LibVersion? depend(LibDepend d, Bool checked := true)
  {
    lib := lib(d.name, false)
    if (lib != null && d.versions.contains(lib.version)) return lib
    if (checked) throw UnknownLibErr(d.toStr)
    return null
  }

}

