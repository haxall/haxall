//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//  4 Apr 2024   Brian Frank  Creation
//

using concurrent
using util
using xeto
using xetom

**
** FileRepoScanner walks thru the Fantom env path to find all the
** libs in "lib/xeto" and "src/xeto".
**
internal class FileRepoScanner
{
  new make(Log log, File[] path)
  {
    this.log   = log
    this.path  = path
  }

  FileRepoScan scan()
  {
    t1 := Duration.now
    path.each |dir|
    {
      scanZips(dir, dir+`lib/xeto/`)
      scanSrcs(dir, dir+`src/xeto/`)
    }
    acc.each |list, name|
    {
      list.sort
    }
    t2 := Duration.now
    log.info("FileRepo scan [" + (t2-t1).toLocale + "]")
    return FileRepoScan(acc)
  }

  private Void scanZips(File pathDir, File libXetoDir)
  {
    libXetoDir.list.each |sub|
    {
      if (sub.isDir) scanZipLib(sub)
    }
  }

  private Void scanZipLib(File dir)
  {
    name := dir.name
    err := XetoUtil.libNameErr(name)
    if (err != null) return log.warn("Invalid lib name $name.toCode [$dir.osPath]")

    dir.list.each |f|
    {
      // only care about files with xetolib extension
      if (f.isDir || f.ext != "xetolib") return

      // parse filename as "{name}-{version}.xetolib"
      Version? version
      basename := f.basename
      if (basename.size >= name.size + 6 && basename[name.size] == '-')
      {
        version = Version.fromStr(basename[name.size+1..-1], false)
        if (version != null && version.segments.size != 3)
          return log.warn("Invalid xetolib version $version [$f.osPath]")
      }
      if (version == null) return log.warn("Invalid xetolib filename [$f.osPath]")

      // add to accumulator (lazily load depends)
      add(FileLibVersion(name, version, f, null, 0, null))
    }
  }

  private Void scanSrcs(File pathDir, File srcXetoDir)
  {
    srcXetoDir.list.each |f|
    {
      if (!f.isDir) return
      lib := f.plus(`lib.xeto`)
      if (lib.exists) scanSrcLib(pathDir, f, lib)
    }
  }

  private Void scanSrcLib(File pathDir, File srcDir, File lib)
  {
    name := srcDir.name
    err := XetoUtil.libNameErr(name)
    if (err != null) return log.warn("Invalid lib name $name.toCode [$srcDir.osPath]")

    entry := parseSrcVersion(name, lib)
    if (entry == null) return

    add(entry)
  }

  private FileLibVersion? parseSrcVersion(Str name, File lib)
  {
    try
    {
      c := XetoCompiler
      {
        it.libName = name
        it.input   = lib
      }
      return c.parseLibVersion
    }
    catch (Err e)
    {
      log.info("Cannot parse lib source meta [$lib.osPath]\n  $e")

      return null
    }
  }

  private Void add(FileLibVersion entry)
  {
    name := entry.name
    list := acc[name]
    if (list == null)
    {
      acc[name] = [entry]
      return
    }

    dupIndex := list.findIndex |x| { x.version == entry.version }
    if (dupIndex == null)
    {
      list.add(entry)
      return
    }

    dup := list[dupIndex]
    if (entry.file.isDir && dup.file.ext == "xetolib")
    {
      // source dir hides xetolib
      list.removeAt(dupIndex)
      list.add(entry)
      return
    }

    log.warn("Dup lib $name.toCode lib hidden [$entry.file.osPath]")
  }

  private Log log
  private File[] path
  private Str:FileLibVersion[] acc := [:]
}

**************************************************************************
** FileRepoScan
**************************************************************************

internal const class FileRepoScan
{
  new make(Str:FileLibVersion[] map)
  {
    this.list = map.keys.sort
    this.map  = map
  }

  const Str[] list
  const Str:FileLibVersion[] map
  const Str ts := DateTime.now.toLocale("YYYY-MM-DD hh:mm:ss")
}

