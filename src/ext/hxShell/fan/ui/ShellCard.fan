//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Jun 2021  Brian Frank  Creation
//

/* This is code is currently used

using graphics
using dom
using domkit
using haystack

**
** ShellCardDeck displays a grid row like Trio
**
@Js
internal class ShellCardDeck : Box
{
  new make(Grid grid)
  {
    this.style->background = "#fff"
    this.style->width  = "100%"
    this.style->height = "100%"
    this.style->overflow = "auto"
    this.style.addClass("domkit-border")

    grid.each |row, i|
    {
      card := ShellCard(row)
      if (i > 0) card.style.addClass("domkit-border-top")
      add(card)
    }
  }
}

**************************************************************************
** ShellCard
**************************************************************************

@Js
internal class ShellCard : GridBox
{
  new make(Dict dict)
  {
    this.style->padding = "8px"
    this.style->height = "auto"

    tags := Box
    {
      it.style->display = "grid"
      it.style->gridTemplateColumns = "auto 1fr"
      it.style->gridColumnGap = "8px"
    }

    dict.each |v, n|
    {
      if (v == null) return
      tags.add(Label { it.text = n; it.style.addClass("card-name") })
      tags.add(toVal(v))
    }

    add(tags)
  }

  private Elem toVal(Obj val)
  {
    if (val is Ref) return toLabel(((Ref)val).toZinc)
    if (val is Dict) return toMultiLine(dictToStr(val))
    if (val is List) return toMultiLine(listToStr(val))
    if (val is Str) return toMultiLine(val, true)
    return toLabel(Etc.valToDis(val))
  }

  private Elem toLabel(Obj val)
  {
    Label { it.text = val.toStr; it.style.addClass("card-val") }
  }

  private Elem toMultiLine(Str s, Bool mono := false)
  {
    lines := s.splitLines
    if (lines.size == 0) return toLabel("")
    if (lines.size == 1) return toLabel(lines[0])
    elem := Box()
    lines.each |line|
    {
      elem.add(Label {
        it.text = line;
        it.style->display = "block";
        it.style->padding = "0";
        it.style.addClass("card-val")
        if (mono) it.style.addClass("mono")
      })
    }
    return elem
  }

  private Str dictToStr(Dict d)
  {
    size := Etc.dictNames(d).size
    if (size <= 1) return Etc.valToDis(d)
    s := StrBuf()
    s.add("{\n")
    d.each |v, n|
    {
      if (v == null) return
      s.add("\u00A0\u00A0")
      s.add(n)
      if (v !== Marker.val) s.add(":").add(Etc.valToDis(v))
      s.addChar('\n')
    }
    return s.add("}").toStr
  }

  private Str listToStr(List list)
  {
    if (list.size == 0) return "[]"
    if (list.size == 1) return "[" + Etc.valToDis(list.first) + "]"
    s := StrBuf()
    s.add("[\n")
    list.each |v, n|
    {
      if (v == null) return
      s.add("\u00A0\u00A0")
      s.add(Etc.valToDis(v)).add("\n")
    }
    return s.add("]").toStr
  }
}
*/