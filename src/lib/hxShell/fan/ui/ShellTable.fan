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
    this.model = ShellTableModel(grid)
    rebuild
  }

  // these must be kept in sync with hxShell.css
  static const Font headerFont := Font("bold 9pt Helvetica")  // 12px * 0.75
  static const Font cellFont   := Font("9.75pt Helvetica")    // 13px * 0.75
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
    return grid.cols.map |col->Int| { initColWidth(grid, col, hm, cm) }
  }

  private static Int initColWidth(Grid grid, Col col, FontMetrics hm, FontMetrics cm)
  {
    // just use first 100 rows
    maxRow := grid.size.min(100)
    prefw := hm.width(col.dis)
    for (rowi := 0; rowi<maxRow; ++rowi)
    {
      row := grid[rowi]
      text := row.dis(col.name)
      textw := cm.width(text)
      prefw = prefw.max(textw)
    }
    prefw = prefw.min(200f)
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
    text := row.dis(col.name)

    cell.text = text
  }

  override Int sortCompare(Int c, Int r1, Int r2)
  {
    col := cols[c]
    a   := grid[r1].val(col)
    b   := grid[r2].val(col)
    return Etc.sortCompare(a, b)
  }

  private Grid grid
  private Col[] cols
  private Int[] colWidths
}