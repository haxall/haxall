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
    return e != null && e.libRef.val != null
  }

  DataLib? load(Str qname, Bool checked := true)
  {
    // check for install
    entry := entry(qname, checked)
    if (entry == null) return null

    // check for cached loaded lib
    lib := entry.libRef.val as DataLib
    if (lib != null) return lib

    // compile the lib into memory and atomically cache once
    entry.libRef.compareAndSet(null, compile(entry))
    return entry.libRef.val
  }

  XetoLibEntry? entry(Str qname, Bool checked)
  {
    x := entries[qname]
    if (x != null) return x
    if (checked) throw UnknownLibErr("Not installed: $qname")
    return null
  }

  DataLib compile(XetoLibEntry entry)
  {
    compilingPush(entry.qname)
    try
    {
      compiler := XetoCompiler
      {
        it.env    = this.env
        it.qname  = entry.qname
        it.input  = entry.src ?: entry.zip
        it.zipOut = entry.zip
      }
      return compiler.compileLib
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
  const AtomicRef libRef := AtomicRef()
  override Str toStr() { "$qname [src: $src, zip: $zip.osPath]" }
}

