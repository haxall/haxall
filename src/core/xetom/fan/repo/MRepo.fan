//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Apr 2026  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack

**
** Base class for all LibRepos
**
@Js
abstract const class MRepo : LibRepo
{
  new make(MEnv env)
  {
    this.env = env
  }

  const MEnv env

  override LibVersion? latest(Str name, Bool checked := true)
  {
    versions := versions(name)
    if (!versions.isEmpty) return versions.last
    if (checked) throw UnknownLibErr(name)
    return null
  }

  override LibVersion? latestMatch(LibDepend d, Bool checked := true)
  {
    versions := versions(d.name)
    if (!versions.isEmpty)
    {
      match := versions.eachrWhile |x| { d.versions.contains(x.version) ? x : null }
      if (match != null) return match
    }
    if (checked) throw UnknownLibErr(d.toStr)
    return null
  }

  override LibVersion? version(Str name, Version version, Bool checked := true)
  {
    versions := versions(name)
    index := versions.binaryFind |x| { version <=> x.version }
    if (index >= 0) return versions[index]
    if (checked) throw UnknownLibErr("$name-$version")
    return null
  }
}

