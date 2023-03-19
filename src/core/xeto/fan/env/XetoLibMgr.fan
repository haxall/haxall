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
    this.path = Env.cur.path.map |dir->File| { dir.plus(`lib/data/`) }
    this.entries = initEntries(this.path)
    this.installed = entries.keys.sort
  }

  private static Str:XetoLibEntry initEntries(File[] path)
  {
    acc := Str:XetoLibEntry[:]
    path.each |pogDir|
    {
      pogDir.listDirs.each |dir|
      {
        doInitInstalled(acc, dir)
      }
    }
    return acc
  }

  private static Void doInitInstalled(Str:XetoLibEntry acc, File dir)
  {
    hasLib := dir.plus(`lib.xeto`).exists
    if (!hasLib) return

    qname := dir.name
    dup := acc[qname]
    if (dup != null) echo("WARN: XetoEnv '$qname' lib hidden [$dup.dir.osPath]")
    acc[qname] = XetoLibEntry(qname, dir)
  }

  Bool isInstalled(Str libName)
  {
    entries[libName] != null
  }

  File? libDir(Str qname, Bool checked)
  {
    entry(qname, checked)?.dir
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
        it.env   = this.env
        it.qname = entry.qname
        it.input = entry.dir
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
  const File[] path
  const Str[] installed
  const Str:XetoLibEntry entries
}

**************************************************************************
** XetoLibEntry
**************************************************************************

@Js
internal const class XetoLibEntry
{
  new make(Str qname, File dir) { this.qname = qname; this.dir = dir }

  const Str qname
  const File dir
  const AtomicRef libRef := AtomicRef()
  override Str toStr() { "$qname [$dir.osPath]" }
}

