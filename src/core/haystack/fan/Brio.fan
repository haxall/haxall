//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Nov 2015  Brian Frank  Creation
//

using concurrent

**
** BrioCtrl defines binary control constants
**
@NoDoc
mixin BrioCtrl
{
  static const Int ctrlNull       := 0x00
  static const Int ctrlMarker     := 0x01
  static const Int ctrlNA         := 0x02
  static const Int ctrlRemove     := 0x03
  static const Int ctrlFalse      := 0x04
  static const Int ctrlTrue       := 0x05
  static const Int ctrlNumberI2   := 0x06
  static const Int ctrlNumberI4   := 0x07
  static const Int ctrlNumberF8   := 0x08
  static const Int ctrlStr        := 0x09
  static const Int ctrlRefStr     := 0x0a
  static const Int ctrlRefI8      := 0x0b
  static const Int ctrlUri        := 0x0c
  static const Int ctrlDate       := 0x0d
  static const Int ctrlTime       := 0x0e
  static const Int ctrlDateTimeI4 := 0x0f  // secs
  static const Int ctrlDateTimeI8 := 0x10  // ns
  static const Int ctrlCoord      := 0x11
  static const Int ctrlXStr       := 0x12
  static const Int ctrlBuf        := 0x13
  static const Int ctrlDictEmpty  := 0x14
  static const Int ctrlDict       := 0x15
  static const Int ctrlListEmpty  := 0x16
  static const Int ctrlList       := 0x17
  static const Int ctrlGrid       := 0x18
  static const Int ctrlSymbol     := 0x19
}

**************************************************************************
** BrioConsts
**************************************************************************

@NoDoc
const class BrioConsts
{
  static BrioConsts cur() { curRef.val }
  private static const AtomicRef curRef := AtomicRef(null)

  static const MimeType mimeType := MimeType("application/x-brio")

  static
  {
    try
    {
      if (Env.cur.runtime != "js")
        curRef.val = load(BrioConsts#.pod.file(`/res/brio-consts.txt`))
    }
    catch (Err e)
      e.trace
  }

  private static BrioConsts load(File f)
  {
    Version? version
    byCode := Str[,] { capacity = 1000 }
    byVal := Str:Int[:]

    byCode.add("")
    byVal.add("", 0)

    f.eachLine |line|
    {
      // first line must be brio-const:version
      if (version == null)
      {
        if (line.startsWith("brio-const:")) throw IOErr(line)
        version = Version.fromStr(line[line.index(":")+1..-1])
        return
      }

      // skip empty or comment lines
      line = line.trim
      if (line.isEmpty || line.startsWith("//")) return

      try
      {
        sp   := line.index(" ")
        code := line[0..<sp].toInt
        val  := line[sp+1..-1]
        if (byCode.size != code) throw Err("$code != $byCode.size")
        byCode.add(val)
        byVal.add(val, code)
      }
      catch (Err e) throw IOErr("Invalid line: $line", e)
    }

    return make
    {
      it.version = version
      it.byCode  = byCode
      it.byVal   = byVal
    }
  }

  private new make(|This| f) { f(this) }

  const Version version
  const Str:Int byVal
  const Str[] byCode

  // Last safe code is 945 (last 3.0.17 code)
  const Int maxSafeCode := 945

  Int? encode(Str val, Int maxStrCode)
  {
    code := byVal[val]
    if (code != null && code <= maxStrCode) return code
    return null
  }

  Int? encodeX(Str val) // encode without maxSafeCode
  {
    byVal[val]
  }

  Str decode(Int code)
  {
    byCode.getSafe(code) ?: throw IOErr("Missing const code $code [$version]")
  }

  Str intern(Str val)
  {
    code := byVal[val]
    if (code == null) return val
    return decode(code)
  }

  /*
  static Void main()
  {
    // rewrite brio-consts.txt
    f := `/work/skyspark/src/core/haystack/res/brio-consts.txt`.toFile
    code := -1
    prev := ""
    skip := true
    out := Env.cur.out
    strs := Str:Str[:]
    f.eachLine |line|
    {
      line = line.trim
      if (line.startsWith("// 3.0.27")) skip = false
      if (skip || line.isEmpty || line.startsWith("//"))
      {
        if (!line.isEmpty && line[0].isDigit)
        {
          code = line.split[0].toInt + 1
          str := line.split[1]
          strs[str] = str
        }
        out.printLine(line)
        return
      }
      sp := line.index(" ")
      val := sp == null ? line : line[sp+1..-1]
      out.printLine("$code $val")
      code++
      if (prev > val) echo("WARN: out of order: $prev $val")
      if (strs[val] != null) echo("WARN: duplicate val: $val")
      prev = val
    }
    out.flush
  }
  */
}

**************************************************************************
** BrioConstTracing
**************************************************************************

/*
  @NoDoc @Axon { admin = true }
  static Grid brioConstDump() { BrioConstTrace.toGrid }

class BrioConstTrace
{
  static Void trace(Str s) { actor.send(s) } // add to encode when code missing

  static Grid toGrid() { actor.send(null).get(1min) }

  private static const Actor actor := Actor(ActorPool()) |msg| { onReceive(msg) }

  private static Obj? onReceive(Obj? msg)
  {
    acc := Actor.locals["acc"] as Str:BrioConstTrace
    if (acc == null) Actor.locals["acc"] = acc = Str:BrioConstTrace[:]
    if (msg == null) return onDump(acc)
    onTrace(acc, msg)
    return null
  }

  private static Grid onDump(Str:BrioConstTrace acc)
  {
    list := acc.vals.sortr |a, b| { a.count <=> b.count }
    gb := GridBuilder().addCol("count").addCol("str")
    gb.capacity = list.size
    list.each |x| { gb.addRow2(Number(x.count), x.s) }
    return gb.toGrid
  }

  private static Void onTrace(Str:BrioConstTrace acc, Str s)
  {
    x := acc[s]
    if (x == null) acc[s] = x = BrioConstTrace(s)
    x.count++
  }

  new make(Str s) { this.s = s }
  const Str s
  Int count
}
*/