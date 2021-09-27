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
    this.edit   = Button { it.text = "Edit";  it.onAction { onEdit }; it.enabled = false }
    this.trash  = Button { it.text = "Trash"; it.onAction { onTrash }; it.enabled = false }
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

  Void update(ShellState old, ShellState cur)
  {
    views.text = sh.state.viewType.dis
    edit.enabled = !cur.selection.isEmpty
    trash.enabled = !cur.selection.isEmpty
  }

  private Void onNew()
  {
    ShellDialog.promptTrio("New", Str<|dis:"New Rec"|>) |recs|
    {
      req := Etc.makeDictsGrid(["commit":"add"], recs)
      sh.session.call("commit", req).onOk |res| { gotoIds(res) }
    }
  }

  private Void onEdit()
  {
    trio := ShellUtil.recsToEditTrio(sh.state.selection)
    ShellDialog.promptTrio("Edit", trio.toStr) |recs|
    {
      req := Etc.makeDictsGrid(["commit":"update"], recs)
      sh.session.call("commit", req).onOk |res| { sh.refresh }
    }
  }

  private Void gotoIds(Grid res)
  {
    ids := res.mapToList |r->Ref| { r.id }
    if (ids.size == 1)
      sh.eval("readById(" + Etc.toAxon(ids.first) + ")", true)
    else
      sh.eval("readByIds(" + Etc.toAxon(ids) + ")", true)
  }

  private Void onTrash()
  {
    sel := sh.state.selection
    aux := sel.size == 1 ? "Selection: " + sel[0].dis : "Selection: $sel.size records"
    ShellDialog.confirm("Move recs to trash?", aux) |->|
    {
      rows := sel.map |r->Dict| { Etc.makeDict3("id", r.id, "mod", r->mod, "trash", Marker.val) }
      req := Etc.makeDictsGrid(["commit":"update"], rows)
      sh.session.call("commit", req).onOk |res| { sh.refresh }
    }
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
        it.onAction { sh.update(sh.state.setViewType(v)) }
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

