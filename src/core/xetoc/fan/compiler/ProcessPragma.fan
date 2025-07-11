//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 May 2023  Brian Frank  Creation
//

using util
using xeto
using xetom

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
      // for libs the pragma defines the depends
      lib.meta = compiler.pragma
      lib.version = toVersion
      pragma.metaParent = lib
      if (lib.name == XetoUtil.projLibName)
        compiler.depends.list = nsToDepends
      else
        compiler.depends.list = pragmaToDepends
    }
    else
    {
      // for data we use the entire ns as our implict resolution depends
      compiler.depends.list = nsToDepends
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

    scalar.asmRef = ver

    return ver
  }

  private MLibDepend[] nsToDepends()
  {
    ns.versions.mapNotNull |lib->MLibDepend?|
    {
      if (compiler.libName == lib.name) return null
      return MLibDepend(lib.name, LibDependVersions.wildcard, FileLoc.synthetic)
    }
  }

  private MLibDepend[] pragmaToDepends()
  {
    if (isSys) return MLibDepend#.emptyList

    list := toDependsList(pragma.get("depends"))

    if (list != null && !list.isEmpty) return list

    if (isLib) err("Must specify 'sys' in depends", pragma.loc)
    return [MLibDepend("sys", LibDependVersions.wildcard, FileLoc.synthetic)]
  }

  private MLibDepend[]? toDependsList(AData? val)
  {
    if (val == null) return null

    // depends list must be respresented in AST as ADict
    alist := val as ADict
    if (alist == null)
    {
      err("Depends must be a list", val.loc)
      return null
    }

    // map list items to MLibDepend objects
    acc := Str:MLibDepend[:]
    acc.ordered = true
    alist.each |obj| { toDepend(acc, obj) }


    // make this list the assembled value
    depends := acc.vals.toImmutable
    alist.asmRef = depends

    return depends
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
    LibDependVersions? versions := LibDependVersions.wildcard
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
    libName = names.toName(names.add(libName))
    acc[libName] = MLibDepend(libName, versions, loc)
  }
}

