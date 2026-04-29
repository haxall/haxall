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
    t2 := Duration.now
    log.info("FileRepo scan [" + (t2-t1).toLocale + "]")
    return FileRepoScan(acc)
  }

//////////////////////////////////////////////////////////////////////////
// Lib Zips
//////////////////////////////////////////////////////////////////////////

  private Void scanZips(File pathDir, File libXetoDir)
  {
    libXetoDir.list.each |f|
    {
      scanZipFile(f)
    }
  }

  private Void scanZipFile(File f)
  {
    if (f.isDir || f.ext != "xetolib") return

    // sanity check name
    name := f.basename
    err := XetoUtil.libNameErr(name)
    if (err != null) return log.warn("Invalid lib name $name.toCode [$f.osPath]")

    try
    {
      // try to parse meta.props
      [Str:Str]? props
      zip := Zip.open(f)
      try
      {
        propsFile := zip.contents.get(`/meta.props`) ?: throw Err("Missing 'meta.props' in zip")
        props = propsFile.readProps
      }
      finally zip.close

      // parse to entry and add to accumulator
      entry := parseZipFile(name, f, props)
      add(entry)
    }
    catch (Err e)
    {
      log.warn("Cannot load lib meta $name.toCode [$f.osPath]", e)
      return null
    }
  }

  private FileLibVersion? parseZipFile(Str name, File file, Str:Str props)
  {
    // version
    version := Version.fromStr(props.getChecked("version"))

    // doc
    doc := props["doc"] ?: ""

    // flags
    flags := 0
    if (props["hxSysOnly"] != null) flags = flags.or(FileLibVersion.flagHxSysOnly)

    // depends
    depends := LibDepend#.emptyList
    dependsStr := props["depends"]?.trimToNull
    if (dependsStr != null) depends = dependsStr.split(';').map |s->LibDepend| { parseDepend(s) }

    // create
    return FileLibVersion(name, version, file, doc, flags, depends)
  }

  private static LibDepend parseDepend(Str s)
  {
    sp := s.index(" ") ?: throw ParseErr("Invalid depend: $s")
    n  := s[0..<sp].trim
    v  := LibDependVersions(s[sp+1..-1])
    return MLibDepend(n, v)
  }

//////////////////////////////////////////////////////////////////////////
// Source
//////////////////////////////////////////////////////////////////////////

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
      c := MXetoCompiler
      {
        it.libName = name
        it.input   = lib
      }
      return c.parseLibMeta
    }
    catch (Err e)
    {
      log.info("Cannot parse lib source meta [$lib.osPath]\n  $e")

      return null
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private Void add(FileLibVersion entry)
  {
    name := entry.name
    dup := acc[name]

    if (dup == null)
    {
      acc[name] = entry
      return
    }

    if (entry.isSrc && dup.file.ext == "xetolib")
    {
      // source dir hides xetolib
      acc[name] = entry
      return
    }

    log.warn("Dup lib $name.toCode lib hidden [$entry.file.osPath]")
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private Log log
  private File[] path
  private Str:FileLibVersion acc := [:]
}

**************************************************************************
** FileRepoScan
**************************************************************************

internal const class FileRepoScan
{
  new make(Str:FileLibVersion map)
  {
    this.list = map.vals.sort |a, b| { a.name <=> b.name }
    this.map  = map
  }

  const FileLibVersion[] list
  const Str:FileLibVersion map
  const Str ts := DateTime.now.toLocale("YYYY-MM-DD hh:mm:ss")
}

