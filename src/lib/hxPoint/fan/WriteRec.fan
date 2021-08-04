//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Jul 2012  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hx

**
** WriteRec models state for a single writable point rec.
**
internal class WriteRec
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(WriteMgr mgr, Ref id, Dict rec)
  {
    this.id = id
    this.rec = rec
    this.levels = WriteLevel?[,] { size = 17 }

    // restore 1, 8, and def from persisted tags
    init(1, "write1")
    init(8, "write8")
    init(17, "writeDef")

    // update initial state
    update(mgr)
  }

  Void init(Int level, Str tag)
  {
    val := rec[tag]
    if (val == null) return
    lvl := WriteLevel()
    lvl.val = val
    lvl.who = "database restore"
    levels[level-1] = lvl
  }

//////////////////////////////////////////////////////////////////////////
// Lifecycle
//////////////////////////////////////////////////////////////////////////

  ** Update rec after a commit has been detected by observation framework
  Void updateRec(Dict rec)
  {
    this.rec = rec
  }

  ** Check periodically if our timed override has expired
  Void check(WriteMgr mgr, Duration now)
  {
    if (overrideExpire != 0 && overrideExpire < now.ticks)
      write(mgr, null, 8, levels[7].who)
  }

//////////////////////////////////////////////////////////////////////////
// Writes
//////////////////////////////////////////////////////////////////////////

  ** Write the given value and level
  Obj? write(WriteMgr mgr, Obj? val, Int level, Obj who)
  {
    // for timed override val is wrapped as TimedOverride
    timed := val as TimedOverride
    if (timed != null) val = timed.val

    // if level 8 check for timed or permanent override
    if (level == 8)
    {
      if (timed != null)
        overrideExpire = Duration.nowTicks + timed.dur.ticks
      else
        overrideExpire = 0
    }

    // update our level data structure
    lvl := levels[level-1]
    if (lvl == null) levels[level-1] = lvl = WriteLevel()

    // short circuit rest of logic if there is no change because
    // its very common for control applications to rewrite
    // the same value+level at a high frequency in control loops
    if (lvl.val == val && whoIsEqual(lvl.who, who)) return val

    // update level val and who
    lvl.val = val
    lvl.who = who

    // determine if we need to persist this write (1, 8, and def)
    if (timed == null)
    {
      switch (level)
      {
        case 1:  persist(mgr, "write1", val)
        case 8:  persist(mgr, "write8", val)
        case 17: persist(mgr, "writeDef", val)
      }
    }

    // update output
    effectiveChange := update(mgr)

    // fire observations
    mgr.fireObservation(this, val, levelNums[level-1], who, effectiveChange)

    return val
  }

  ** Check if previous who is equal to new who
  private static Bool whoIsEqual(Obj? a, Obj? b)
  {
    // evaluate if we still need this...

    // schedules pass a grid with future data one week into
    // the future; so check the meta.mod to see if anything
    // has actually changed
    aGrid := a as Grid; if (aGrid == null) return a == b
    bGrid := b as Grid; if (bGrid == null) return false

    // check meta 'mod' tag
    aMod := aGrid.meta["mod"]
    bMod := bGrid.meta["mod"]
    return aMod == bMod
  }

  ** Make persistent Folio commit to level1, level8, or levelDef
  private Void persist(WriteMgr mgr, Str tag, Obj? val)
  {
    if (rec[tag] == val) return
    rec = mgr.rt.db.commit(Diff(rec, Etc.makeDict1(tag, val ?: Remove.val), Diff.force)).newRec
  }

  ** Update effective value and level.  Return true if there is an effective
  ** change and sink it to Folio as a transient commit via WriteMgr.sink
  private Bool update(WriteMgr mgr)
  {
    // compute new write val/level
    level := levelNums.last
    val := null
    who := null
    for (i:=0; i<17; ++i)
    {
      lvl := levels[i]
      if (lvl == null || lvl.val == null) continue
      level = levelNums[i]
      val = lvl.val
      who = lvl.who
      break
    }

    // if not an effective change, then short circuit and return false
    if (val == lastVal && level == lastLevel) return false

    // sink effective change to folio and return true
    lastVal = val
    lastLevel = level
    try
      mgr.sink(this, val, level, who)
    catch (ShutdownErr e)
      { /* ignore */ }
    catch (Err e)
      mgr.lib.log.err("writeSink", e)
    return true
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Debug details as shows up in connector screens
  Str toDetails()
  {
    s := StrBuf()
    s.add("Writable\n")
    s.add("=============================\n")
    s.add("Level   Val          Who\n")
    s.add("-----   ----------   --------\n")
    levels.each |level, i|
    {
      lvl := i + 1
      val := level?.val ?: "null"
      who := level?.whoToStr ?: ""
      if (i == 7 && overrideExpire > 0)
      {
        left := Duration(overrideExpire).minus(Duration.now).abs
        who += " (expires in $left.toLocale)"
      }
      s.add(lvl.toStr.padr(5)).add("   ")
       .add(val.toStr.padr(10)).add("    ")
       .add(who)
       .add("\n")
    }
    s.add("\n")
    return s.toStr
  }

  ** Get current state of writable priority array as grid
  Grid toGrid()
  {
    // writeVal, writeLevel meta
    meta := Str:Obj[:]
    meta.addNotNull("writeVal", rec["writeVal"])
    meta.addNotNull("writeLevel", rec["writeLevel"])

    // parse enum
    Str[] enum := Str#.emptyList
    try
      if (rec.has("enum")) enum = HxUtil.parseEnumNames(rec["enum"].toStr)
    catch (Err e) {}

    // build grid
    gb := GridBuilder()
    gb.capacity = 17
    gb.setMeta(meta)
      .addCol("level").addCol("levelDis").addCol("val")
      .addCol("valDis").addCol("who").addCol("expires")
    for (i:=0; i<17; ++i)
    {
      lvl := levels[i]
      val := null
      Str? who := null

      if (lvl != null)
      {
        val = lvl.val
        who = lvl.whoToStr
      }

      valDis := val == null ? null : val.toStr
      if (val is Bool && enum.size == 2)
      {
        e := enum[val ? 1 : 0]
        if (!e.isEmpty) valDis = e
      }

      expires := null
      if (i == 7 && overrideExpire > 0)
      {
        left := Duration(overrideExpire).minus(Duration.now).abs
        expires = Number.makeDuration(left, null)
      }

      gb.addRow([Number.makeInt(i+1), levelDis[i], val, valDis, who, expires])
    }
    return gb.toGrid
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  ** Level display names to use in toGrid
  static const Str[] levelDis :=
  [
    "1 (emergency)", "2", "3", "4", "5", "6", "7", "8 (manual)",
    "9", "10", "11", "12", "13", "14", "15", "16", "def"
  ]

  ** Levels as Number (zero based)s
  static const Number[] levelNums
  static
  {
    list := Number[,]
    for (i:=0; i<17; ++i) list.add(Number.makeInt(i+1))
    levelNums = list
  }

  const Ref id                      // record id
  Dict rec { private set }          // current state of record
  private WriteLevel?[] levels      // index 0 => level 1, index 17 -> def
  private Obj? lastVal              // last value written
  private Number? lastLevel         // last level written
  private Int overrideExpire        // Duration ticks to send 8 back to auto or zero
}

**************************************************************************
** TimedOverride
**************************************************************************

internal const class TimedOverride
{
  new make(Obj? val, Duration dur) { this.val = val; this.dur = dur }
  const Obj? val
  const Duration dur
}

**************************************************************************
** WriteLevel
**************************************************************************

internal class WriteLevel
{
  ** Current value to write
  Obj? val

  ** Who set the level to this value; if a schedule set
  ** this level then who is a Grid with the schedule's weekly timeline
  Obj? who

  Str? whoToStr()
  {
    if (who is Grid) return ((Grid)who).meta["who"] ?: "Grid?"
    return who
  }
}