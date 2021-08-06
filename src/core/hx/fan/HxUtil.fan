//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Jun 2021  Brian Frank  Creation
//

using [java]java.lang::Thread as JavaThread
using [java]java.lang.management
using [java]java.lang::StackTraceElement

using haystack
using axon
using def
using folio

**
** Haxall utility methods
**
const class HxUtil
{

//////////////////////////////////////////////////////////////////////////
// Folio Utils
//////////////////////////////////////////////////////////////////////////

  ** Coerce a value to a Ref identifier:
  **   - Ref returns itself
  **   - Row or Dict, return 'id' tag
  **   - Grid return first row id
  static Ref toId(Obj? val)
  {
    if (val is Ref) return val
    if (val is Dict) return ((Dict)val).id
    if (val is Grid) return ((Grid)val).first.id
    throw Err("Cannot convert to id: ${val?.typeof}")
  }

  ** Coerce a value to a list of Ref identifiers:
  **   - Ref returns itself as list of one
  **   - Ref[] returns itself
  **   - Dict return 'id' tag
  **   - Dict[] return 'id' tags
  **   - Grid return 'id' column
  static Ref[] toIds(Obj? val)
  {
    if (val is Ref) return Ref[val]
    if (val is Dict) return Ref[((Dict)val).id]
    if (val is List)
    {
      list := (List)val
      if (list.isEmpty) return Ref[,]
      if (list.of.fits(Ref#)) return list
      if (list.all |x| { x is Ref }) return Ref[,].addAll(list)
      if (list.all |x| { x is Dict }) return list.map |Dict d->Ref| { d.id }
    }
    if (val is Grid)
    {
      grid := (Grid)val
      if (grid.meta.has("navFilter"))
        return Slot.findMethod("legacy::NavFuncs.toNavFilterRecIdList").call(grid)
      ids := Ref[,]
      idCol := grid.col("id")
      grid.each |row|
      {
        id := row.val(idCol) as Ref ?: throw Err("Row missing id tag")
        ids.add(id)
      }
      return ids
    }
    throw Err("Cannot convert to ids: ${val?.typeof}")
  }

  ** Coerce a value to a record Dict:
  **   - Row or Dict returns itself
  **   - Grid returns first row
  **   - List returns first row (can be either Ref or Dict)
  **   - Ref will make a call to read database
  static Dict toRec(HxRuntime rt, Obj? val)
  {
    if (val is Dict) return val
    if (val is Grid) return ((Grid)val).first ?: throw Err("Grid is empty")
    if (val is List) return toRec(rt, ((List)val).first ?: throw Err("List is empty"))
    if (val is Ref)  return rt.db.readById(val)
    throw Err("Cannot convert toRec: ${val?.typeof}")
  }

  ** Coerce a value to a list of record Dicts:
  **   - null return empty list
  **   - Ref or Ref[] (will make a call to read database)
  **   - Row or Row[] returns itself
  **   - Dict or Dict[] returns itself
  **   - Grid is mapped to list of rows
  static Dict[] toRecs(HxRuntime rt, Obj? val)
  {
    if (val == null) return Dict[,]

    if (val is Dict) return Dict[val]

    if (val is Ref) return Dict[rt.db.readById(val)]

    if (val is Grid)
    {
      grid := (Grid)val
      if (grid.meta.has("navFilter"))
        return Slot.findMethod("legacy::NavFuncs.toNavFilterRecList").call(grid)
      return grid.toRows
    }

    if (val is List)
    {
      list := (List)val
      if (list.isEmpty) return Dict[,]
      if (list.of.fits(Dict#)) return list
      if (list.all |x| { x is Dict }) return Dict[,].addAll(list)
      if (list.all |x| { x is Ref }) return rt.db.readByIdsList(list, true)
      throw Err("Cannot convert toRecs: List of ${list.first?.typeof}")
    }

    throw Err("Cannot convert toRecs: ${val?.typeof}")
  }

  ** Implementation for readAllTagNames function
  internal static Grid readAllTagNames(Folio db, Filter filter)
  {
    acc := Str:TagNameUsage[:]
    db.readAllEachWhile(filter, Etc.emptyDict) |rec|
    {
      rec.each |v, n|
      {
        u := acc[n]
        if (u == null) acc[n] = u = TagNameUsage()
        u.add(v)
      }
      return null
    }
    gb := GridBuilder().addCol("name").addCol("kind").addCol("count")
    acc.keys.sort.each |n|
    {
      u := acc[n]
      gb.addRow([n, u.toKind, Number(u.count)])
    }
    return gb.toGrid
  }

  ** Implementation for readAllTagVals function
  internal static Obj[] readAllTagVals(Folio db, Filter filter, Str tagName)
  {
    acc := Obj:Obj[:]
    db.readAllEachWhile(filter, Etc.emptyDict) |rec|
    {
      val := rec[tagName]
      if (val != null) acc[val] = val
      return acc.size > 200 ? "break" : null
    }
    return acc.vals.sort
  }

//////////////////////////////////////////////////////////////////////////
// Enum
//////////////////////////////////////////////////////////////////////////

  **
  ** Convenience for parseEnum which returns only a list of
  ** string names.  Using this method is more efficient than
  ** calling parseEnums and then mapping the keys.
  **
  static Str[] parseEnumNames(Obj? enum)
  {
    DefUtil.parseEnumNames(enum)
  }

  **
  ** Parse enum as ordered map of Str:Dict keyed by name.  Dict tags:
  **   - name: str key
  **   - doc: fandoc string if available
  **
  ** Supported inputs:
  **   - null returns empty list
  **   - Dict of Dicts
  **   - Str[] names
  **   - Str newline separated names
  **   - Str comma separated names
  **   - Str fandoc list as - name: fandoc lines
  **
  static Str:Dict parseEnum(Obj? enum)
  {
    DefUtil.parseEnum(enum)
  }

//////////////////////////////////////////////////////////////////////////
// Process & Threads
//////////////////////////////////////////////////////////////////////////

  ** Process id or null if cannot be determined
  static Int? pid() { HxThreadDump.pid }

  ** Current thread id
  static Int threadId() { JavaThread.currentThread.getId }

  ** Dump all threads
  static Str threadDumpAll() { HxThreadDump().toAll }

  ** Dump thread deadlocks if detected
  static Str threadDumpDeadlocks()  { HxThreadDump().toDeadlocks }

  ** Dump a specific thread by its id
  static Str threadDump(Int id) { HxThreadDump().toThread(id) }

//////////////////////////////////////////////////////////////////////////
// Internal
//////////////////////////////////////////////////////////////////////////

  ** Get current context
  private static HxContext curContext() { HxContext.curHx }
}

**************************************************************************
** HxThreadDump
**************************************************************************

internal class HxThreadDump
{
  static Int? pid()
  {
    try
    {
      // use reflection to access Java 9 API so we can run in Java 8
      // ProcessHandle.current().pid()
      type := Type.find("[java]java.lang::ProcessHandle")
      cur := type.method("current").callOn(null, null)
      return type.method("pid").callOn(cur, null)
    }
    catch (Err e)
    {
      return null
    }
  }

  Str? toDeadlocks() { dump(true) }

  Str toAll() { dump(false) }

  Str toThread(Int id)
  {
    ThreadInfo[] infos := bean.dumpAllThreads(true, true)
    info := infos.find |info| { info.getThreadId == id }
    if (info == null) return "ThreadDump: id not found: $id"
    dumpStack(HxThread(bean, info))
    return buf.toStr
  }

  private Str? dump(Bool deadlocksOnly)
  {
    // get all threads
    ThreadInfo[] infos := bean.dumpAllThreads(true, true)
    HxThread[] threads := infos.map |info->HxThread| { HxThread(bean, info) }
    threads.each |t| { byId[t.id] = t }

    // find deadlocks
    buf.add("\n")
    deadlocked := bean.findDeadlockedThreads
    haveDeadlocks := deadlocked != null && deadlocked.size > 0
    if (haveDeadlocks)
    {
      buf.add("  ### Deadlock Detected ###\n\n")
      for (i := 0; i<deadlocked.size; ++i)
      {
        id := deadlocked[i]
        t := byId[id]
        if (t !=null) dumpStack(t)
      }
    }
    if (deadlocksOnly) return haveDeadlocks ? buf.toStr : null

    // dump by CPU
    buf.add("  ### CPU Time ###\n\n")
    threads.sortr |a, b| { a.cpu <=> b.cpu }
    threads.each |t| { if (t.cpu > 1ms) buf.add("  $t.name [$t.cpu.toLocale]\n") }
    buf.add("\n")

    // stack trace
    buf.add("  ### Stack Traces ###\n\n")
    threads.sort |a, b| { a.name <=> b.name }
    threads.each |t| { dumpStack(t) }
    return buf.toStr
  }

  private Void dumpStack(HxThread t)
  {
    StackTraceElement[] elems := t.info.getStackTrace
    if (elems.isEmpty) return

    buf.add("  $t.name [$t.info.getThreadId: $t.info.getThreadState]\n")

    lock := t.info.getLockInfo
    owner := t.info.getLockOwnerName
    if (lock != null)
    {
      buf.add("    - waiting to lock: $lock\n")
      if (owner != null)
        buf.add("    - lock held by: $owner\n")
    }

    MonitorInfo[] monitors := t.info.getLockedMonitors

    elems.each |elem|
    {
      m := monitors.find |x| { x.getLockedStackFrame === elem }
      buf.add("    $elem\n")
      if (m != null) buf.add("    - locked: $m\n")
    }
    buf.add("\n")
  }

  private ThreadMXBean bean := ManagementFactory.getThreadMXBean
  private StrBuf buf := StrBuf() { capacity = 4096 }
  private Int:HxThread byId := [:]
}


internal class HxThread
{
  new make(ThreadMXBean bean, ThreadInfo info)
  {
    this.info = info
    this.name = info.getThreadName
    this.id   = info.getThreadId
    this.cpu  = Duration(bean.getThreadCpuTime(info.getThreadId))
  }

  ThreadInfo info
  const Int id
  const Str name
  const Duration cpu
}


