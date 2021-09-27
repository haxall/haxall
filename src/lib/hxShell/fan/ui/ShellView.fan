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
internal class ShellView : Box
{
  new make(Shell sh)
  {
    this.sh = sh
    updateTextArea("Try out some Axon!")
  }

  Void update(ShellState old, ShellState cur)
  {
    // short circuit if no changes to grid or view type
    if (old.grid === cur.grid && old.viewType === cur.viewType) return

    removeAll
    switch (cur.viewType)
    {
      case ShellViewType.table: updateTable
      case ShellViewType.text:  updateText
      case ShellViewType.csv:   updateGridWriter(CsvWriter#)
      case ShellViewType.json:  updateGridWriter(JsonWriter#)
      case ShellViewType.trio:  updateGridWriter(TrioWriter#)
      case ShellViewType.zinc:  updateGridWriter(ZincWriter#)
      default: add(Label { it.text = "Unsupported: $cur.viewType" })
    }
  }

  private Void updateErr()
  {
    meta := sh.grid.meta
    add(Box {
      it.style.addClass("domkit-border")
      it.style->background = "#fff"
      it.style->padding = "12px"
      it.style->height = "calc(100% - 18px)"
      it.style->overflow = "auto"
      ShellUtil.errElemBig(meta.dis),
      Elem("pre") { it.text = meta["errTrace"] ?: "No trace" },
    })
  }

  private Void updateTable()
  {
    if (sh.grid.isErr) return updateErr
    table := ShellTable(sh.grid)
    {
      it.onSelect { sh.update(sh.state.setSelection(it.sel.items)) }
    }
    add(table)
  }

  private Void updateText()
  {
    if (sh.grid.isErr) return updateErr
    str := Etc.gridToStrVal(sh.grid, null)
    if (str == null)
    {
      buf := StrBuf()
      sh.grid.dump(buf.out, ["noClip":true])
      str = buf.toStr
    }
    updateTextArea(str)
  }

  private Void updateGridWriter(Type type)
  {
    buf := StrBuf()
    writer := (GridWriter)type.make([buf.out])
    writer.writeGrid(sh.grid)
    updateTextArea(buf.toStr)
  }

  private Void updateTextArea(Str val)
  {
    add(TextArea { it.val = val })
  }

  private Shell sh
}

**************************************************************************
** ShellViewType
**************************************************************************

@Js
internal enum class ShellViewType
{
  table("Table"),
  text("Text"),
  csv("CSV"),
  json("JSON"),
  trio("Trio"),
  zinc("Zinc")

  private new make(Str dis) { this.dis = dis }

  const Str dis

  static ShellViewType toBest(Grid grid)
  {
    view := grid.meta["view"] as Str
    if (view == "text") return text
    return table
  }
}

