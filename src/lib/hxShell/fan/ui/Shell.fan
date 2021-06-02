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
    sh.input.focus
  }

  ** Constructor
  new make()
  {
    // title bar
    titleBar := FlexBox
    {
      it.flex = ["0 0 auto", "0 0 auto"]
      it.style->padding = "0 8px"
      it.style->background = "#798ba4"
      Label
      {
        it.text = Win.cur.doc.title
        it.style->fontSize = "20px"
        it.style->fontWeight = "bold"
        it.style->color = "white"
      },
      Label
      {
        it.text = session.user.dis
        it.style->fontSize = "14px"
        it.style->color = "white"
        it.style->marginLeft = "auto"  // flexbox parent will align right
      },
    }

    // input bar
    inputBar := Box
    {
      it.style->padding = "8px"
      input,
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
    viewBox := Box
    {
      it.style->padding = "8px"
      view,
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
      viewBox,
    })
  }

  ** Evaluate the given expression
  Void eval(Str expr)
  {
    session.eval(expr).onOk |grid|
    {
      this.cur = grid
      view.update(grid)
    }
  }

  ** Client session to make HTTP API calls
  const Session session := Session()

  ** Current grid result
  internal Grid cur := Etc.emptyGrid

  ** Input prompt
  internal ShellInput input := ShellInput(this)

  ** View box
  internal ShellView view := ShellView()
}

