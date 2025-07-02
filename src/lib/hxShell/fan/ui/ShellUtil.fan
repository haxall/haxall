//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Jun 2021  Brian Frank  Creation
//

using dom
using domkit
using xeto
using haystack

**
** ShellView is used to display the current grid
**
@Js
internal const class ShellUtil
{
  ** Error message with unhappy face (big for shell main pane)
  static Elem errElemBig(Str dis)
  {
    Elem("h1")
    {
      it.style->margin = "0"
      Elem("span") { it.text = "\u2639"; it.style.addClass("err-icon-big") },
      Elem("span") { it.text = dis; it.style.addClass("err-dis-big")  },
    }
  }

  ** Error message with unhappy face (small for dialog flash)
  static Elem errElemSmall(Str dis)
  {
    Elem("h1")
    {
      it.style->margin = "0"
      Elem("span") { it.text = "\u2639"; it.style.addClass("err-icon-small") },
      Elem("span") { it.text = dis; it.style.addClass("err-dis-small")  },
    }
  }

  ** Format list of records to trio for editing
  static Str recsToEditTrio(Dict[] recs)
  {
    buf := StrBuf()
    recs.each |rec, i|
    {
      if (i > 0) buf.add("---\n")
      buf.add(recToEditTrio(rec))
    }
    return buf.toStr
  }

  ** Format record to trio for editing by commenting out non-editable tags
  static Str recToEditTrio(Dict rec)
  {
    good := Str:Obj?[:] { ordered = true }
    bad := Str:Obj[:] { ordered = true }
    rec.each |v, n|
    {
      if (nonEditableTags.contains(n))
        bad[n] = v
      else
        good[n] = v
    }

    buf := StrBuf()
    TrioWriter(buf.out).writeDict(Etc.makeDict(good))
    if (!bad.isEmpty)
    {
      badBuf := StrBuf()
      badBuf.add("restricted/transient tags\n")
      TrioWriter(badBuf.out).writeDict(Etc.makeDict(bad))
      badBuf.toStr.splitLines.each |line| { if (!line.isEmpty) buf.add("// ").add(line).add("\n") }
    }
    return buf.toStr
  }

  ** These is a copy of folio::DiffTagRule for restricted and transient
  static const Str[] nonEditableTags := "projMeta,ext,connState,connStatus,connErr,curVal,curStatus,curErr,writeVal,writeLevel,writeStatus,writeErr,hisStatus,hisErr,hisSize,hisStart,hisStartVal,hisEnd,hisEndVal".split(',')
}

