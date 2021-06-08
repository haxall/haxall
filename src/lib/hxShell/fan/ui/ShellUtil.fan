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


}

