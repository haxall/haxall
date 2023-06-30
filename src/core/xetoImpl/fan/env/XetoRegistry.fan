//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Dec 2022  Brian Frank  Creation
//

using util
using concurrent
using data
using haystack::UnknownLibErr

**
** XetoRegistry manages the cache and loading of the environments libs
**
@Js
internal const class XetoRegistry : DataRegistry
{
  new make(XetoEnv env)
  {
    this.env     = env
    this.libPath = Env.cur.path.map |dir->File| { dir.plus(`lib/xeto/`) }
    this.map     = discover(this.libPath)
    this.list    = map.vals.sort |a, b| { a.qname <=> b.qname }
  }

  override XetoRegistryLib? get(Str qname, Bool checked := true)
  {
    x := map[qname]
    if (x != null) return x
    if (checked) throw UnknownLibErr("Not installed: $qname")
    return null
  }

  private static Str:XetoRegistryLib discover(File[] libPath)
  {
    acc := Str:XetoRegistryLib[:]

    // find all lib/xeto entries
    libPath.each |dir|
    {
      dir.list.each |f|
      {
        if (!f.isDir && f.ext == "xetolib")
          doInitInstalled(acc, f.basename, null, f)
      }
    }

    // recursively find source entires
    initSrcEntries(acc, Env.cur.workDir + `src/xeto/`)

    return acc
  }

  private static Void initSrcEntries(Str:XetoRegistryLib acc, File dir)
  {
    qname := dir.name
    lib := dir + `lib.xeto`
    if (lib.exists)
    {
      doInitInstalled(acc, qname, dir, Env.cur.workDir + `lib/xeto/${qname}.xetolib`)
    }
    else
    {
      dir.listDirs.each |subDir| { initSrcEntries(acc, subDir) }
    }
  }

  private static Void doInitInstalled(Str:XetoRegistryLib acc, Str qname, File? src, File zip)
  {
    dup := acc[qname]
    if (dup != null)
    {
      if (dup.zip != zip) echo("WARN: XetoEnv '$qname' lib hidden [$dup.zip.osPath]")
    }
    acc[qname] = XetoRegistryLib(qname, src, zip)
  }

  DataLib? load(Str qname, Bool checked := true)
  {
    // check for install
    entry := get(qname, checked)
    if (entry == null) return null

    // check for cached loaded lib
    if (entry.isLoaded) return entry.get

    // compile the lib into memory and atomically cache once
    return compile(entry, null)
  }

  override Int build(DataRegistryLib[] libs)
  {
    // create a XetoLibEntry copy for each entry
    build := Str:XetoRegistryLib[:]
    build.ordered = true
    libs.each |x|
    {
      build[x.qname] = XetoRegistryLib(x.qname, x.srcDir, x.zip)
    }

    // now build using build entries for dependencies
    try
    {
      build.each |entry|
      {
        if (!entry.isLoaded) compile(entry, build)
      }
      return 0
    }
    catch (Err e)
    {
      echo("BUILD FAILED")
      return 1
    }
  }

  XetoLib? resolve(XetoCompiler c, Str qname)
  {
    // in build mode use build entries for depends
    if (c.isBuild)
    {
      entry := c.build[qname]
      if (entry != null)
      {
        if (entry.isLoaded) return entry.get
        return compile(entry, c.build)
      }
    }

    // use normal load code path
    return load(qname, false)
  }

  DataLib compile(XetoRegistryLib entry, [Str:XetoRegistryLib]? build)
  {
    compilingPush(entry.qname)
    try
    {
      // compile
      compiler := XetoCompiler
      {
        it.env     = this.env
        it.qname   = entry.qname
        it.input   = entry.src ?: entry.zip
        it.zipOut  = entry.zip
        it.build   = build
      }
      lib := compiler.compileLib

      // atomically set entry and return
      entry.set(lib)
      return entry.get
    }
    finally
    {
      compilingPop
    }
  }

  private Void compilingPush(Str qname)
  {
    stack := Actor.locals[compilingKey] as Str[]
    if (stack == null) Actor.locals[compilingKey] = stack = Str[,]
    if (stack.contains(qname)) throw Err("Cyclic lib dependency: $stack")
    stack.push(qname)
  }

  private Void compilingPop()
  {
    stack := Actor.locals[compilingKey] as Str[]
    if (stack == null) return
    stack.pop
    if (stack.isEmpty) Actor.locals.remove(compilingKey)
  }

  const XetoEnv env
  const File[] libPath
  override const XetoRegistryLib[] list
  const Str:XetoRegistryLib map
  const Str compilingKey := "dataEnv.compiling"
}

**************************************************************************
** XetoRegistryLib
**************************************************************************

@Js
internal const class XetoRegistryLib : DataRegistryLib
{
  new make(Str qname, File? src, File zip)
  {
    this.qname   = qname
    this.src     = src
    this.zip     = zip
  }

  override const Str qname

  override const File zip

  override Version version()
  {
    isLoaded ? get.version : Version.defVal
  }

  override Str doc()
  {
    isLoaded ? (get["doc"] as Str ?: "") : ""
  }

  override Bool isLoaded() { libRef.val != null }

  override Str toStr() { "$qname [src: $src, zip: $zip.osPath]" }

  override Bool isSrc() { src != null }

  override File? srcDir(Bool checked := true)
  {
    if (src != null) return src
    if (checked) throw Err("Lib source not available: $qname")
    return null
  }

  const File? src

  DataLib get() { libRef.val ?: throw Err("Not loaded: $qname") }

  Void set(DataLib lib) { libRef.compareAndSet(null, lib) }

  private const AtomicRef libRef := AtomicRef()
}

