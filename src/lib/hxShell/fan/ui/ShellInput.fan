//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Jun 2021  Brian Frank  Creation
//

using dom
using domkit
using haystack
using hx

**
** Axon expression input with MRU history
**
@Js
internal class ShellInput : Box
{
  new make(Shell sh)
  {
    this.sh = sh
    this.prompt = TextField
    {
      it.style->width = "100%"
      it.onEvent("keydown",  false) |e| { onKeyDown(e) }
    }
    this.add(prompt)
  }

  private Void onKeyDown(Event e)
  {
    switch (e.key)
    {
      case Key.enter: e.stop; onEval
      case Key.up:    e.stop; onArrowUp
      case Key.down:  e.stop; onArrowDown
    }
  }

  override Void focus()
  {
    prompt.focus
  }

  private Void update(Str expr)
  {
    prompt.val = expr
    prompt.select(expr.size, expr.size)
  }

  private Void onEval()
  {
    expr := prompt.val.trim
    if (expr.size == 0) return
    his.push(expr)
    update("")
    sh.eval(expr)
  }

  private Void onArrowUp()
  {
    expr := his.up
    if (expr != null)
      update(expr)
  }

  private Void onArrowDown()
  {
    expr := his.down
    if (expr != null)
      update(expr)
    else
      onRecent
  }

  private Void onRecent()
  {
    menu := Menu
    {
      it.style->width = "${prompt.size.w.toInt}px"
      it.style->height = "60%"
      it.onClose { prompt.focus }
    }

    his.list.each |x|
    {
      menu.add(MenuItem {
        it.text = x
        it.onAction { update(x) }
      })
    }

    p := prompt.pagePos
    menu.select(0)
    menu.open(p.x, p.y + prompt.size.h)
  }

  private Shell sh
  private TextField prompt
  private ShellHistory his := ShellHistory()
}

**************************************************************************
** ShellHistory
**************************************************************************

@Js
internal class ShellHistory
{
  new make()
  {
    try
    {
      str := dom::Win.cur.localStorage[key] as Str ?: ""
      this.list = str.isEmpty ? Str[,] : str.split(nc)
    }
    catch (Err e)
    {
      e.trace
    }
  }

  Str[] list := [,]

  Int index := -1

  Str? up()
  {
    if (index+1 >= list.size) return null
    val := list[++index]
    return val
  }

  Str? down()
  {
    if (index-1 < 0) return null
    val := list[--index]
    return val
  }

  Void push(Str item)
  {
    list  = list.insert(0, item).unique
    if (list.size > max) list = list[0..<max]
    Win.cur.localStorage[key] = list.join(nc.toChar)
    index = -1
  }

  private const Str key := "hxShell.his"
  private const Int nc := 0   // ASCII null char
  private const Int max := 25
}


