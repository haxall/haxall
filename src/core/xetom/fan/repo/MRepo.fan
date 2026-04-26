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

  ** Utility to filter a list of options with opts to implement
  ** the standard LibRepo.versions behavior
  static LibVersion[] findAllVersionsWithOpts(LibVersion[]? list, Dict? opts)
  {
    // if null
    if (list == null) return LibVersion#.emptyList

    // contrainsts
    versions := XetoUtil.optVersionConstraints(opts)
    if (versions != null) list = list.findAll { versions.contains(it.version) }

    // limit
    limit := XetoUtil.optInt(opts, "limit", Int.maxVal)
    if (list.size > limit) list = list[0..<limit]
    return list
  }

  ** Default routes to versions with '{limit:1}'
  override LibVersion? latest(Str name, Bool checked := true)
  {
    opts := Etc.dict1("limit", 1)
    x := versions(name, opts).first
    if (x != null) return x
    if (checked) throw UnknownLibErr(name)
    return null
  }

  ** Default routes to versions with '{limit:1, versions:d.versions}'
  override LibVersion? latestMatch(LibDepend d, Bool checked := true)
  {
    opts := Etc.dict2("limit", 1, "versions", d.versions)
    x := versions(d.name, opts).first
    if (x != null) return x
    if (checked) throw UnknownLibErr(d.toStr)
    return null
  }

  ** Default routes to versions with '{limit:1, versions:version}'
  override LibVersion? version(Str name, Version version, Bool checked := true)
  {
    x := versions(name, Etc.dict1("versions", LibDependVersions(version))).first
    if (x != null) return x
    if (checked) throw UnknownLibErr("$name-$version")
    return null
  }
}

