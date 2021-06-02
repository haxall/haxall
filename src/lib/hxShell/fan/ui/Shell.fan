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
** Shell top level page
**
@Js
class Shell : Box
{
  ** Main entry point to mount shell into DOM
  static Void main()
  {
    sh := Shell()
    Win.cur.doc.body.add(sh)
  }

  ** Constructor
  new make()
  {
    // title bar
    titleBar := Box
    {
      it.style->padding = "0 8px"
      it.style->background = "#798ba4"
      Label
      {
        it.text = Win.cur.doc.title
        it.style->fontSize = "16pt"
        it.style->fontWeight = "bold"
        it.style->color = "white"
      },
    }

    // input bar
    inputBar := Box
    {
      it.style->padding = "8px"
      TextField
      {
        it.style->width = "100%"
      },
    }

    // tool bar
    toolBar := FlexBox
    {
      it.flex = ["0 0 auto", "0 0 auto"]
      it.style->padding = "0 8px"
      FlowBox
      {
        it.gaps = ["4px"]
        Button { it.text = "New" },
        Button { it.text = "Edit" },
        Button { it.text = "Trash" },
      },
      Button
      {
        it.text = "Table"
        it.style->marginLeft = "auto"  // flexbox parent will align right
      },
    }

    // view box
    textBox := TextArea {}
    view := Box
    {
      it.style->padding = "8px"
      textBox,
    }

    // put it all together
    add(FlexBox
    {
      it.flex = ["0 0 auto", "0 0 auto", "0 0 auto",  "1 1 auto"]
      it.dir = "column"
      it.style->width = "100%"
      it.style->padding = "0"
      titleBar,
      inputBar,
      toolBar,
      view,
    })

    session.eval("id").onOk |grid|
    {
      textBox.val = ZincWriter.valToStr(grid)
    }
  }

  ** Client session back to server
  const Session session := Session()
}

