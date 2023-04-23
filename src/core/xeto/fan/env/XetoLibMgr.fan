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
** XetoLibMgr manages the cache and loading of the environments libs
**
@Js
internal const class XetoLibMgr
{
  new make(XetoEnv env)
  {
    this.env = env
    this.libPath = Env.cur.path.map |dir->File| { dir.plus(`lib/xeto/`) }
    this.entries = initEntries(this.libPath)
    this.installed = entries.keys.sort
  }

  private static Str:XetoLibEntry initEntries(File[] libPath)
  {
    acc := Str:XetoLibEntry[:]

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

  private static Void initSrcEntries(Str:XetoLibEntry acc, File dir)
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

  private static Void doInitInstalled(Str:XetoLibEntry acc, Str qname, File? src, File zip)
  {
    dup := acc[qname]
    if (dup != null)
    {
      if (dup.zip != zip) echo("WARN: XetoEnv '$qname' lib hidden [$dup.zip.osPath]")
    }
    acc[qname] = XetoLibEntry(qname, src, zip)
  }

  Bool isInstalled(Str libName)
  {
    entries[libName] != null
  }

  Bool isLoaded(Str qname)
  {
    e := entry(qname, false)
    return e != null && e.isLoaded
  }

  DataLib? load(Str qname, Bool checked := true)
  {
    // check for install
    entry := entry(qname, checked)
    if (entry == null) return null

    // check for cached loaded lib
    if (entry.isLoaded) return entry.get

    // compile the lib into memory and atomically cache once
    return compile(entry, null)
  }

  Int build(Str[] qnames)
  {
    // create a XetoLibEntry copy for each entry
    build := Str:XetoLibEntry[:]
    build.ordered = true
    qnames.each |qname|
    {
      entry := entry(qname, true)
      if (entry.src == null) throw Err("No source for lib: $qname")
      build[qname] = XetoLibEntry(qname, entry.src, entry.zip)
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

  XetoLibEntry? entry(Str qname, Bool checked)
  {
    x := entries[qname]
    if (x != null) return x
    if (checked) throw UnknownLibErr("Not installed: $qname")
    return null
  }

  DataLib compile(XetoLibEntry entry, [Str:XetoLibEntry]? build)
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
  const Str compilingKey := "dataEnv.compiling"
  const File[] libPath
  const Str[] installed
  const Str:XetoLibEntry entries
}

**************************************************************************
** XetoLibEntry
**************************************************************************

@Js
internal const class XetoLibEntry
{
  new make(Str qname, File? src, File zip)
  {
    this.qname = qname
    this.src   = src
    this.zip   = zip
  }

  const Str qname
  const File? src
  const File zip

  override Str toStr() { "$qname [src: $src, zip: $zip.osPath]" }

  Bool isLoaded() { libRef.val != null }

  DataLib get() { libRef.val ?: throw Err("Not loaded: $qname") }

  Void set(DataLib lib) { libRef.compareAndSet(null, lib) }

  private const AtomicRef libRef := AtomicRef()
}

