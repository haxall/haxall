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
    ShellDialog.promptTrio("New", Str<|dis:"New Rec"|>) |recs|
    {
      req := Etc.makeDictsGrid(["commit":"add"], recs)
      sh.session.call("commit", req).onOk |res|
      {
        ids := res.mapToList |r->Ref| { r.id }
        if (ids.size == 1)
          sh.eval("readById(" + Etc.toAxon(ids.first) + ")", true)
        else
          sh.eval("readByIds(" + Etc.toAxon(ids) + ")", true)
      }
    }
  }

  private Void onEdit()
  {
    ShellDialog.openErr("Edit not done yet")
  }

  private Void onTrash()
  {
    ShellDialog.openErr("Trash not done yet")
  }

  private Void onMeta()
  {
    grid := sh.grid
    s := StrBuf()
    s.add("=== grid ===\n")
    s.add(TrioWriter.dictToStr(grid.meta))
    grid.cols.each |col|
    {
      s.add("\n=== col $col.name ===\n")
      s.add(TrioWriter.dictToStr(col.meta))
    }
    ShellDialog.openText("Grid Meta", s.toStr)
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

