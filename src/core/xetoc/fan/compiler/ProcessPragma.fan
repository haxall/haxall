//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 May 2023  Brian Frank  Creation
//

using util
using xeto
using xetoEnv

**
** Extract lib metadata from pragma and set fields:
**   - XetoCompiler.depends
**   - ALib.version
**
internal class ProcessPragma : Step
{
  override Void run()
  {
    if (isLib)
    {
      lib.meta = compiler.pragma
      lib.version = toVersion
      compiler.depends.list = toDepends
    }
    else
    {
      compiler.depends.list = toDepends
    }
  }

  private Version toVersion()
  {
    obj := pragma.get("version")
    if (obj == null)
    {
      err("Missing required version lib meta", pragma.loc)
      return Version.defVal
    }

    scalar := obj as AScalar
    if (scalar == null)
    {
      err("Version must be scalar", obj.loc)
      return Version.defVal
    }

    verStr := scalar.str
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

  private MLibDepend[] toDepends()
  {
    if (isSys) return MLibDepend#.emptyList

    acc := Str:MLibDepend[:]
    acc.ordered = true

    list := pragma.get("depends")
    if (list != null)
    {
      if (list isnot ADict)
        err("Depends must be a list", list.loc)
      else
        ((ADict)list).each |obj| { toDepend(acc, obj) }
    }

    // if not specified, assume just sys
    if (acc.isEmpty)
    {
      if (isLib) err("Must specify 'sys' in depends", pragma.loc)
      acc["sys"] = MLibDepend("sys", MLibDependVersions.wildcard, FileLoc.synthetic)
    }

    return acc.vals
  }

  private Void toDepend(Str:MLibDepend acc, AData obj)
  {
    // get library name from depend formattd as "{lib:<qname>}"
    loc := obj.loc

    dict := obj as ADict
    if (dict == null) return err("Depend must be dict", loc)

    libName := dict.getStr("lib")
    if (libName == null) return err("Depend missing lib name", loc)

    // get versions
    MLibDependVersions? versions := MLibDependVersions.wildcard
    versionsObj := dict.get("versions")
    if (versionsObj != null)
    {
      versionsStr := (versionsObj as AScalar)?.str
      if (versionsStr == null) return err("Versions must be a scalar", versionsObj.loc)

      versions = LibDependVersions(versionsStr, false)
      if (versions == null) return err("Invalid versions syntax: $versionsStr", versionsObj.loc)
    }

    // register the library into our names table and our depends map
    if (acc[libName] != null) return err("Duplicate depend '$libName'", loc)
    env.names.add(libName)
    acc[libName] = MLibDepend(libName, versions, loc)
  }
}

