//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Aug 2023  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack::UnknownLibErr

**
** FileRepo is a file system based repo that uses the the Fantom path to
** find zip versions in "lib/xeto/" and sourceversion in "src/xeto/".
**
@Js
const class FileRepo : LibRepo
{
  new make(File[] path := Env.cur.path)
  {
    this.path = path
    rescan
  }

  const Log log := Log.get("xeto")

  const File[] path

  internal FileRepoScan scan() { scanRef.val }
  private const AtomicRef scanRef := AtomicRef()

  override Str toStr() { "$typeof.qname ($scan.ts.toLocale)" }

  override This rescan()
  {
    scanRef.val = FileRepoScanner(log, path).scan
    return this
  }

  override Str[] libs()
  {
    scan.list
  }

  override LibVersion[]? versions(Str name, Bool checked := true)
  {
    versions := scan.map.get(name)
    if (versions != null) return versions
    if (checked) throw UnknownLibErr(name)
    return null
  }

  override LibVersion? latest(Str name, Bool checked := true)
  {
    versions := versions(name, checked)
    if (versions != null) return versions.last
    if (checked) throw UnknownLibErr(name)
    return null
  }

  override LibVersion? version(Str name, Version version, Bool checked := true)
  {
    versions := versions(name, checked)
    if (versions != null)
    {
      index := versions.binaryFind |x| { version <=> x.version }
      if (index >= 0) return versions[index]
    }
    if (checked) throw UnknownLibErr("$name-$version")
    return null
  }

  override LibVersion[] solveDepends(LibVersion[] libs)
  {
    if (libs.isEmpty) throw Err("No libs specified")
    if (libs.size == 1 && libs.first.name == "sys") return libs.dup
    throw Err("TODO")
  }
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

**************************************************************************
** FileRepoScanner
**************************************************************************

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
      add(name, version, f, null)
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

    zip := pathDir + `lib/xeto/${name}/${name}-${version}.xetolib`
    add(name, version, zip, srcDir)
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

  private Void add(Str name, Version version, File zip, File? srcDir)
  {
    list := acc[name]
    entry := FileLibVersion(name, version, zip, srcDir)
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
      else if (dup.zip.osPath == zip.osPath)
      {
        FileLibVersion#srcDir->setConst(dup, srcDir)
      }
      else
      {
        log.warn("Dup lib $name.toCode lib hidden [$dup.zip.osPath]")
      }
    }
  }

  private Log log
  private File[] path
  private Str:FileLibVersion[] acc := [:]
}

