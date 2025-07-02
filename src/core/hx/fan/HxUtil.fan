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

using xeto
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
// Folio
//////////////////////////////////////////////////////////////////////////

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
// Axon Support
//////////////////////////////////////////////////////////////////////////

  ** List pods as grid
  static Grid pods()
  {
    gb := GridBuilder()
    gb.addCol("name").addCol("version")
      .addCol("buildTime").addCol("buildHost")
      .addCol("org").addCol("project")
      .addCol("summary")
    Pod.list.each |p|
    {
      m := p.meta
      DateTime? ts
      try
        ts = DateTime.fromStr(m["build.ts"]).toTimeZone(TimeZone.cur)
      catch {}
      gb.addRow([p.name, p.version.toStr,
                ts, m["build.host"],
                m["org.name"], m["proj.name"],
                m["pod.summary"]])
    }
    return gb.toGrid
  }

  ** List timezones as grid
  static Grid tzdb()
  {
    gb := GridBuilder()
    gb.setMeta(["cur":TimeZone.cur.name])
    gb.addCol("name").addCol("fullName")
    TimeZone.listFullNames.each |fn|
    {
      slash := fn.indexr("/")
      n := slash == null ? fn : fn[slash+1..-1]
      gb.addRow2(n, fn)
    }
    return gb.toGrid
  }

  ** List units as grid
  static Grid unitdb()
  {
    gb := GridBuilder()
    gb.addCol("quantity").addCol("name").addCol("symbol")
    Unit.quantities.each |q|
    {
      Unit.quantity(q).each |u|
      {
        gb.addRow([q, u.name, u.symbol])
      }
    }
    return gb.toGrid
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
    __noJava := true

    ThreadInfo[] infos := bean.dumpAllThreads(true, true)
    info := infos.find |info| { info.getThreadId == id }
    if (info == null) return "ThreadDump: id not found: $id"
    dumpStack(HxThread(bean, info))
    return buf.toStr
  }

  private Str? dump(Bool deadlocksOnly)
  {
    __noJava := true

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
    __noJava := true

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

