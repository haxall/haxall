//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 May 2023  Brian Frank  Creation
//

using util
using xeto

**
** Extract lib metadata from pragma and set fields:
**   - XetoCompiler.depends
**   - ALib.version
**
@Js
internal class ProcessPragma : Step
{
  override Void run()
  {
    if (isLib)
    {
      if (pragma?.meta?.slots == null) throw err("No lib pragma", lib.loc)
      lib.version = toVersion
      compiler.depends = toDepends
    }
    else
    {
      compiler.depends = toDepends
    }
  }

  private Version toVersion()
  {
    obj := pragma.meta.slot("version")
    if (obj == null)
    {
      err("Missing required version lib meta", pragma.loc)
      return Version.defVal
    }

    if (obj.val == null)
    {
      err("Version must be scalar", obj.loc)
      return Version.defVal
    }

    verStr := obj.val.str
    ver := Version.fromStr(verStr, false)
    if (ver == null)
    {
      err("Invalid version: $verStr", obj.loc)
      return Version.defVal
    }

    if (ver.segments.size != 3)
    {
      err("Xeto version must be exactly three segments: $ver", obj.loc)
      return ver
    }

    return ver
  }

  private XetoLibDepend[] toDepends()
  {
    if (isSys) return XetoLibDepend#.emptyList

    acc := Str:XetoLibDepend[:]
    acc.ordered = true

    list := pragma?.meta?.slot("depends")
    if (list != null)
    {
      list.slots.each |obj| { toDepend(acc, obj) }
    }

    // if not specified, assume just sys
    if (acc.isEmpty)
    {
      if (isLib) err("Must specify 'sys' in depends", pragma.loc)
      acc["sys"] = XetoLibDepend("sys", XetoLibDependVersions.wildcard, FileLoc.synthetic)
    }

    return acc.vals
  }

  private Void toDepend(Str:XetoLibDepend acc, AObj obj)
  {
    // get library name from depend formattd as "{lib:<qname>}"
    loc := obj.loc
    libName := (obj.slot("lib")?.val as AScalar)?.str
    if (libName == null) return err("Depend missing lib name", loc)

    // get versions
    XetoLibDependVersions? versions := XetoLibDependVersions.wildcard
    versionsObj := obj.slot("versions")
    if (versionsObj != null)
    {
      versionsStr := (versionsObj?.val as AScalar)?.str
      if (versionsStr == null) return err("Versions must be a scalar", versionsObj.loc)

      versions = XetoLibDependVersions(versionsStr, false)
      if (versions == null) return err("Invalid versions syntax: $versionsStr", versionsObj.loc)
    }

    // register the library into our depends map
    if (acc[libName] != null) return err("Duplicate depend '$libName'", loc)
    acc[libName] = XetoLibDepend(libName, versions, loc)
  }

}