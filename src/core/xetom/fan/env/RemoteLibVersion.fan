//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Aug 2022  Brian Frank  Creation
//

using util
using concurrent
using xeto

**
** RemoteLibVersion is used for both RemoteEnv and RemoteRepo
**
@Js
const class RemoteLibVersion : LibVersion
{
  new make(Str name, Version version, Str doc := "", LibDepend[]? depends := null, Str? digest := null, LibPubStatus pubStatus := LibPubStatus.unknown, Str? pubStatusMsg := null)
  {
    this.name         = name
    this.version      = version
    this.doc          = doc
    this.toStr        = "$name-$version"
    this.dependsRef   = depends
    this.digest       = digest
    this.pubStatus    = pubStatus
    this.pubStatusMsg = pubStatusMsg
  }

  ** Construct from a RepoLib dict as defined by `RepoServer.toRepoLib`.
  ** Values may carry their in-process or wire types: version as Version
  ** or Str; each depend as a LibDepend, a dict or map with lib/versions
  ** keys, or a "name versions" string.
  new makeDict(Dict dict)
  {
    this.name         = dict->lib.toStr
    this.version      = Version.fromStr(dict->version.toStr)
    this.doc          = dict["doc"] as Str ?: ""
    this.toStr        = "$name-$version"
    this.dependsRef   = parseDepends(dict["depends"])
    this.digest       = dict["digest"] as Str
    this.pubStatus    = LibPubStatus.fromStr(dict["pubStatus"]?.toStr ?: "", false) ?: LibPubStatus.unknown
    this.pubStatusMsg = dict["pubStatusMsg"] as Str
  }

  ** Parse depends list flavors; null if not reported
  private static LibDepend[]? parseDepends(Obj? val)
  {
    list := val as List
    if (list == null) return null
    return list.map |x->LibDepend| { parseDepend(x) }
  }

  private static LibDepend parseDepend(Obj x)
  {
    if (x is LibDepend) return x
    d := x as Dict
    if (d != null) return LibDepend(d->lib.toStr, LibDependVersions.fromStr(d->versions.toStr))
    m := x as Map
    if (m != null) return LibDepend(m.getChecked("lib").toStr, LibDependVersions.fromStr(m.getChecked("versions").toStr))
    s := x.toStr
    sp := s.index(" ") ?: throw ParseErr("Invalid depend: $s")
    return LibDepend(s[0..<sp].trim, LibDependVersions.fromStr(s[sp+1..-1].trim))
  }

  override const Str name

  override const Version version

  override const Str doc

  override const Str? digest

  override const LibPubStatus pubStatus

  override const Str? pubStatusMsg

  override LibOrigin? origin(Bool checked := true)
  {
    if (checked) throw Err("No origin for '$name'")
    return null
  }

  override Int flags() { 0 } // not supported client side

  override File? file(Bool checked := true)
  {
    if (checked) throw UnsupportedErr()
    return null
  }

  override Bool isSrc() { false }

  override Bool isNotFound() { false }

  override Bool isCompanion() { name == XetoUtil.companionLibName }

  override Void eachSrcFile(|File| f) {}

  override const Str toStr

  override LibDepend[]? depends(Bool checked := true)
  {
    if (dependsRef != null) return dependsRef
    if (checked) throw UnsupportedErr("Depends not available")
    return null
  }
  const LibDepend[]? dependsRef

}

