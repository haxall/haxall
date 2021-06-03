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
** ShellCommands displays and processes the command buttons
**
@Js
internal class ShellCommands : FlexBox
{
  new make(Shell sh)
  {
    this.sh = sh
    this.newRec = Button { it.text = "New";   it.onAction { onNew } }
    this.edit   = Button { it.text = "Edit";  it.onAction { onEdit } }
    this.trash  = Button { it.text = "Trash"; it.onAction { onTrash } }
    this.meta   = Button { it.text = "Meta";  it.onAction { onMeta } }

    this.views = Button {
      it.style.addClass("disclosure")
      it.onPopup { onViews }
      it.style->marginLeft = "auto"  // flexbox parent will align right
    }

    this.flex = ["0 0 auto", "0 0 auto"]
    this.add(FlowBox
    {
      it.gaps = ["4px", "4px", "16px"]
      newRec,
      edit,
      trash,
      meta,
    })
    this.add(views)
  }

  Void update()
  {
    views.text = sh.viewType.dis
  }

  private Void onNew()
  {
    echo("onNew")
  }

  private Void onEdit()
  {
    echo("onEdit")
  }

  private Void onTrash()
  {
    echo("onTrash")
  }

  private Void onMeta()
  {
    echo("onMeta")
  }

  private Popup onViews()
  {
    menu := Menu {}
    ShellViewType.vals.each |v|
    {
      menu.add(MenuItem {
        it.text = v.dis
        it.onAction { sh.update(sh.grid, v) }
      })
    }
    return menu
  }

  private Shell sh
  private Button newRec
  private Button edit
  private Button trash
  private Button meta
  private Button views
}

