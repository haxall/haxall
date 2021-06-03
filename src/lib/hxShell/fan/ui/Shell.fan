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
** Shell top level page
**
@Js
internal class Shell : Box
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

    // command bar
    commandBar := Box
    {
      it.style->padding = "0 8px"
      commands,
    }

    // view box
    viewBox := Box
    {
      it.style->padding = "8px"
      this.style->height = "100%"
      view,
    }

    // put it all together
    add(FlexBox
    {
      it.flex = ["none", "none", "none",  "1 1 0"]
      it.dir = "column"
      it.style->width = "100%"
      it.style->padding = "0"
      titleBar,
      inputBar,
      commandBar,
      viewBox,
    })
  }

  ** Evaluate the given expression
  Void eval(Str expr)
  {
    session.eval(expr).onOk |grid| { update(grid, ShellViewType.table) }
  }

  ** Update shell state
  Void update(Grid grid, ShellViewType viewType)
  {
    this.grid = grid
    this.viewType = viewType
    view.update
    commands.update
    input.focus
  }

  ** Client session to make HTTP API calls
  const Session session := Session()

  ** Current grid result
  internal Grid grid := Etc.emptyGrid

  ** Current grid view type
  internal ShellViewType viewType := ShellViewType.table

  ** Input prompt
  internal ShellInput input := ShellInput(this)

  ** Toolbar commands
  internal ShellCommands commands := ShellCommands(this)

  ** View box
  internal ShellView view := ShellView(this)
}

