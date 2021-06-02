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
** ShellView is used to display the current grid
**
@Js
internal class ShellView : Box
{
  new make()
  {
    dis = TextArea
    {
      it.style.addClass("mono")
      it.style->whiteSpace = "pre"
    }
    add(dis)
  }

  Void update(Grid g)
  {
    dis.val = ZincWriter.gridToStr(g)
  }

  private TextArea dis
}