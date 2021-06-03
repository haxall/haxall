//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Jun 2021  Brian Frank  Creation
//

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

      label := Label
      {
        it.text = n
        it.style.addClass("card-name")
      }

      value := Label
      {
        it.text = ShellUtil.valToDis(v)
        it.style.addClass("card-val")
      }

      tags.add(label)
      tags.add(value)
    }

    add(tags)
  }
}