//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Jun 2021  Brian Frank  Creation
//

using graphics
using dom
using domkit
using haystack

**
** ShellView is used to display the current grid
**
@Js
internal class ShellTable : Table
{
  new make(Grid grid)
  {
    this.sel.multi = true
    this.model = ShellTableModel(grid)
    this.onTableEvent("mousedown") |e| { onMouseDown(e) }
    rebuild
  }

  private Void onMouseDown(TableEvent e)
  {
    if (e.col == 0 && e.cellPos.x <= 20f) onInfo(e)
  }

  private Void onInfo(TableEvent e)
  {
    model := (ShellTableModel)this.model
    row := model.grid[e.row]
    info := Elem("pre")
    {
      it.style.addClass("mono")
      it.style->padding = "0 16px"
      it.text = TrioWriter.dictToStr(row)
    }
    Popup
    {
      Box()
      {
        it.style->overflow = "auto"
        info,
      },
    }.open(e.pagePos.x, e.pagePos.y)
  }

  // these must be kept in sync with hxShell.css
  static const Font headerFont := Font("bold 9pt Helvetica")  // 12px * 0.75
  static const Font cellFont   := Font("9.75pt Helvetica")    // 13px * 0.75

  static const Str infoIcon := "\u24D8\u00A0\u00A0"
}

**************************************************************************
** ShellTableModel
**************************************************************************

@Js
internal class ShellTableModel : TableModel
{
  new make(Grid grid)
  {
    this.grid = grid
    this.cols = grid.cols
    this.colWidths = initColWidths(grid)
  }

  private static Int[] initColWidths(Grid grid)
  {
    hm := ShellTable.headerFont.metrics
    cm := ShellTable.cellFont.metrics
    return grid.cols.map |col, i->Int| { initColWidth(grid, col, i, hm, cm) }
  }

  private static Int initColWidth(Grid grid, Col col, Int index, FontMetrics hm, FontMetrics cm)
  {
    // just use first 100 rows
    maxRow := grid.size.min(100)
    prefw := hm.width(col.dis)
    for (rowi := 0; rowi<maxRow; ++rowi)
    {
      row := grid[rowi]
      text := row.disOf(col) ?: ""
      textw := cm.width(text)
      prefw = prefw.max(textw)
    }
    prefw = prefw.min(200f)
    if (index == 0) prefw += cm.width(ShellTable.infoIcon)
    return prefw.toInt + 12
  }

  override Int numCols() { cols.size }

  override Int numRows() { grid.size }

  override Void onHeader(Elem header, Int c)
  {
    header.text = cols[c].dis
  }

  override Int colWidth(Int c) { colWidths[c] }

  override Obj item(Int r) { grid[r] }

  override Void onCell(Elem cell, Int c, Int r, TableFlags flags)
  {
    col  := cols[c]
    row  := grid[r]
    val  := row.val(col)
    text := row.disOf(col) ?: ""

    if (c == 0) text = ShellTable.infoIcon + text

    cell.text = text
  }

  override Int sortCompare(Int c, Int r1, Int r2)
  {
    col := cols[c]
    a   := grid[r1].val(col)
    b   := grid[r2].val(col)
    return Etc.sortCompare(a, b)
  }

  const Grid grid
  private Col[] cols
  private Int[] colWidths
}

