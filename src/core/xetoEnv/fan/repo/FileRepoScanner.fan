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
using haystack::UnknownLibErr

**
** FileRepoScanner walks thru the Fantom env path to find all the
** libs in "lib/xeto" and "src/xeto".
**
@Js
internal class FileRepoScanner
{
  new make(Log log, File[] path)
  {
    this.log  = log
    this.path = path
  }

  FileRepoScan scan()
  {
    path.each |dir|
    {
      scanZips(dir, dir+`lib/xeto/`)
      scanSrcs(dir, dir+`src/xeto/`)
    }
    acc.each |list, name|
    {
      list.sort
    }
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

      // add to accumulator
      add(name, version, f)
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

    version := parseSrcVersion(lib)
    if (version == null) return

    add(name, version, srcDir)
  }

  private Version? parseSrcVersion(File lib)
  {
    try
    {
      // for performance we assume version is on a line by itself like
      // version: "0.0.1"
      lines := lib.readAllLines
      version := lines.eachWhile |line|
      {
        line = line.trim
        if (!line.startsWith("version")) return null
        colon := line.index(":") ?: throw Err("No colon: $line")
        quoted := line[colon+1..-1].trim
        if (quoted[0] != '"' || quoted[-1] != '"') throw Err("Version not quoted: $line")
        return Version.fromStr(quoted[1..-2])
      }
      return version ?: throw Err("Cannot find version line")
    }
    catch (Err e)
    {
      log.info("Cannot lib source version [$lib.osPath]\n  $e")
      return null
    }
  }

  private Void add(Str name, Version version, File file)
  {
    list := acc[name]
    entry := FileLibVersion(name, version, file, null)
    if (list == null)
    {
      acc[name] = [entry]
    }
    else
    {
      dup := list.find |x| { x.version == version }
      if (dup == null)
      {
        list.add(entry)
      }
      else if (file.isDir && dup.file.ext == "xetolib")
      {
        // source dir hides xetolib
        FileLibVersion#fileRef->setConst(dup, file)
      }
      else
      {
        log.warn("Dup lib $name.toCode lib hidden [$dup.file.osPath]")
      }
    }
  }

  private Log log
  private File[] path
  private Str:FileLibVersion[] acc := [:]
}

**************************************************************************
** FileRepoScan
**************************************************************************

@Js
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

