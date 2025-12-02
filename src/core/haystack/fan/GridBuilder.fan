//
// Copyright (c) 2014, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Mar 2014  Brian Frank  Creation
//

using concurrent
using xeto

**
** GridBuilder is used to build up an immutable `Grid`.  To use first
** define your cols via `addCol` and then add the rows via `addRow`:
**
**    gb := GridBuilder()
**    gb.addCol("a").addCol("b")
**    gb.addRow(["a-0", "b-0"])
**    gb.addRow(["a-1", "b-1"])
**    grid := gb.toGrid
**
@Js
class GridBuilder
{
  ** Set the grid meta (overwrites any current meta)
  ** The meta parameter can be any `Etc.makeDict` value.
  This setMeta(Obj? meta)
  {
    this.meta = Etc.makeDict(meta)
    return this
  }

  ** Number of columns added to the grid
  Int numCols() { cols.size }

  ** Number of rows added to the grid
  Int numRows() { rows.size }

  ** Return if given column name has been defined
  @NoDoc Bool hasCol(Str name)
  {
    if (colsByName == null) finishCols
    return colsByName.containsKey(name)
  }

  ** Map column name to its cell index or raise UnknownNameErr
  @NoDoc Int colNameToIndex(Str name)
  {
    if (colsByName == null) finishCols
    col := colsByName[name]
    if (col == null) throw UnknownNameErr("Col not defined: $name")
    return col.index
  }

  ** Add column to the grid.
  ** The meta parameter can be any `Etc.makeDict` value.
  This addCol(Str name, Obj? meta := null)
  {
    if (colsByName != null) throw Err("Cannot add cols after adding rows")
    if (!Etc.isTagName(name)) throw ArgErr("Invalid col name: $name")
    cols.add(GbCol(cols.size, name, Etc.makeDict(meta)))
    return this
  }

  ** Add list of column names to the grid.
  This addColNames(Str[] names)
  {
    names.each |n| { addCol(n) }
    return this
  }

  ** Add list of cells as a new row to the grid.
  ** The cell list size must match the number of columns.
  This addRow(Obj?[] cells)
  {
    if (colsByName == null) finishCols
    if (cells.size != cols.size) throw ArgErr("Num cells $cells.size != Num cols $cols.size")
    this.rows.add(GbRow(gridRef, cells))
    return this
  }

  ** Add row with one column/cell
  @NoDoc This addRow1(Obj? cell)
  {
    if (colsByName == null) finishCols
    if (cols.size != 1) throw ArgErr("Num cells 1 != Num cols $cols.size")
    this.rows.add(GbRow(gridRef, [cell]))
    return this
  }

  ** Add row with two columns/cells
  @NoDoc This addRow2(Obj? a, Obj? b)
  {
    if (colsByName == null) finishCols
    if (cols.size != 2) throw ArgErr("Num cells 2 != Num cols $cols.size")
    this.rows.add(GbRow(gridRef, [a, b]))
    return this
  }

  ** Add row with three columns/cells
  @NoDoc This addRow3(Obj? a, Obj? b, Obj? c)
  {
    if (colsByName == null) finishCols
    if (cols.size != 3) throw ArgErr("Num cells 3 != Num cols $cols.size")
    this.rows.add(GbRow(gridRef, [a, b, c]))
    return this
  }

  ** Add row with four columns/cells
  @NoDoc This addRow4(Obj? a, Obj? b, Obj? c, Obj? d)
  {
    if (colsByName == null) finishCols
    if (cols.size != 4) throw ArgErr("Num cells 4 != Num cols $cols.size")
    this.rows.add(GbRow(gridRef, [a, b, c, d]))
    return this
  }

  ** Convience for adding a list of `addDictRow`.
  This addDictRows(Dict?[] rows)
  {
    rows.each |row| { addDictRow(row) }
    return this
  }

  ** Add all the rows of given grid as rows to our grid
  This addGridRows(Grid grid)
  {
    grid.each |row| { addDictRow(row) }
    return this
  }

  ** Add dict as a new row to the grid.  All the dict tags
  ** must have been defined as columns.
  This addDictRow(Dict? row)
  {
    if (colsByName == null) finishCols

    // null row is all nulls
    if (row == null)
    {
      rows.add(GbRow(gridRef, Obj?[,] { size = cols.size }))
      return this
    }

    // optimize copying GbRows from a grid with dup columns
    if (row is GbRow)
    {
      gbRow := (GbRow)row
      if (gbRow.grid == copyGrid)
      {
        rows.add(GbRow(gridRef, gbRow.cells))
        return this
      }
    }

    cells := Obj?[,]
    cells.size = cols.size
    row.each |v, n|
    {
      // map value into cells by index
      col := colsByName[n]
      if (col != null) cells[col.index] = v
    }

    rows.add(GbRow(gridRef, cells))
    return this
  }

  ** Construt a grid of one column called 'grid' and rows of
  ** zinc encoded grids.  Null grids are skipped.
  @NoDoc This addGridsAsZincRows(Grid?[] grids)
  {
    more := grids.any |g| { g.meta.has("more") }
    setMeta(more ? ["more":Marker.val] : null)
    addCol("grid")
    grids.each |g| { if (g != null) addRow1(ZincWriter.gridToStr(g)) }
    return this
  }

  ** Add history data as rows joined by timestamp.  The individual
  ** HisItem[] must be presorted by timetamps. The column definitions
  ** must include a 'ts' column and value column for for 'items.size'.
  ** This method must only be called once with all the data to join.
  @NoDoc This addHisItemRows(HisItem[][] pts)
  {
    // setup/checking
    if (colsByName == null) finishCols
    if (cols.first.name != "ts") throw ArgErr("First col not ts")
    if (numCols() != 1+pts.size) throw ArgErr("Incorrect num cols")

    // zero points
    if (pts.isEmpty) return this

    // one point optimization
    if (pts.size == 1)
    {
      pt := pts.first
      rows.capacity = pt.size
      pt.each |item| { addRow2(item.ts, item.val) }
      return this
    }

    // multiple points
    rowsByTs := DateTime:Obj?[][:]
    pts.each |pt, i|
    {
      valIndex := 1 + i
      pt.each |item|
      {
        row := rowsByTs[item.ts]
        if (row == null)
        {
          row = Obj?[,]
          row.size = numCols
          row[0] = item.ts
          rowsByTs[item.ts] = row
        }
        row[valIndex] = item.val
      }
    }

    // map rows to list sorted by timetamp
    rows := rowsByTs.vals
    rows.sort |a, b| { a[0] <=> b[0] }
    rows.each |row| { addRow(row) }
    return this
  }

  ** Copy meta and cols from source grid
  @NoDoc This copyMetaAndCols(Grid src)
  {
    this.meta = src.meta
    return copyCols(src)
  }

  ** Copy meta and cols from source grid
  @NoDoc This copyCols(Grid src)
  {
    if (src is GbGrid)
    {
      x := (GbGrid)src
      this.copyGrid = x
      this.cols = x.cols
      this.colsByName = x.colsByName
    }
    else
    {
      src.cols.each |c| { addCol(c.name, c.meta) }
    }
    return this
  }

  ** Sort the rows by column name before converting to grid
  @NoDoc This sortCol(Str colName)
  {
    if (colsByName == null) finishCols
    c := colsByName[colName] ?: throw Err("Column not found: $colName")
    rows.sort |a, b| { a.cells[c.index] <=> b.cells[c.index] }
    return this
  }

  ** Reverse sort the rows by column name before converting to grid
  @NoDoc This sortrCol(Str colName)
  {
    if (colsByName == null) finishCols
    c := colsByName[colName] ?: throw Err("Column not found: $colName")
    rows.sortr |a, b| { a.cells[c.index] <=> b.cells[c.index] }
    return this
  }

  ** Sort the rows using Etc.compareDis for given column
  @NoDoc This sortDis(Str colName := "id")
  {
    if (colsByName == null) finishCols
    c := colsByName[colName] ?: throw Err("Column not found: $colName")
    try
      rows.sort |a, b| { Etc.compareDis(cellToDis(a, c), cellToDis(b, c)) }
    catch
      rows.sort |a, b| { cellToDis(a, c) <=> cellToDis(b, c) }
    return this
  }

  private static Str cellToDis(GbRow row, GbCol col)
  {
    val := row.cells[col.index]
    return (val as Ref)?.dis ?: val.toStr
  }

  ** Reverse order of the rows before converting to grid
  @NoDoc This reverseRows()
  {
    rows.reverse
    return this
  }

  ** Construct to finalized grid
  Grid toGrid()
  {
    if (colsByName == null) finishCols
    if (cols.isEmpty) throw Err("Must have at least one col")
    grid := GbGrid(meta, cols, colsByName, rows)
    gridRef.val = grid
    return grid
  }

  ** Map cols to map and lock down their definition
  private Void finishCols()
  {
    acc := Str:GbCol[:]
    cols.each |col|
    {
      if (acc[col.name] != null) throw Err("Duplicate col name: $col.name")
      acc[col.name] = col
    }
    colsByName = acc
  }

  ** Replace existing GbCol with new meta
  internal Void setColMeta(Str colName, Dict meta)
  {
    c := cols.find |c| { c.name == colName }
    if (c == null) throw Err("Column not found: $colName")
    c = GbCol(c.index, colName, meta)
    if (cols.isRO) cols = cols.rw
    cols[c.index] = c
    if (colsByName != null)
    {
      if (colsByName.isRO) colsByName = colsByName.rw
      colsByName[colName] = c
    }
  }

  ** Capacity for rows list
  @NoDoc Int capacity
  {
    get { rows.capacity }
    set { rows.capacity = it }
  }

  ** Given a list of arbitrary column names, clean them
  ** up to ensure they are valid tag names and no duplicates
  @NoDoc static Str[] normColNames(Str[] colNames)
  {
    colNames = colNames.dup
    dups := Str:Str[:]
    colNames.each |colName, i|
    {
      // ensure name is safe and unique
      colName = colName.trim
      if (colName.isEmpty) colName = "blank"
      n := Etc.toTagName(colName)
      if (dups[n] != null)
      {
        j := 1
        while (dups["${n}_${j}"] != null) j++
        n = "${n}_${j}"
      }
      colNames[i] = n
      dups[n] = n
    }
    return colNames
  }

  private AtomicRef gridRef := AtomicRef()
  private Dict meta := Etc.dict0
  private GbCol[] cols := [,]
  private [Str:GbCol]? colsByName
  private GbRow[] rows := [,]
  private GbGrid? copyGrid
}

@Js
internal const class GbGrid : Grid
{
  new make(Dict meta, GbCol[] cols, Str:GbCol colsByName, GbRow[] rows)
  {
    this.meta = meta
    this.cols = cols
    this.colsByName = colsByName
    this.rows = rows
  }

  const override Dict meta
  const override Col[] cols
  const Str:GbCol colsByName
  const GbRow[] rows

  override Col? col(Str name, Bool checked := true)
  {
    col := colsByName[name]
    if (col != null || !checked) return col
    throw UnknownNameErr(name)
  }

  override Void each(|Row,Int| f) { rows.each(f) }
  override Obj? eachWhile(|Row,Int->Obj?| f) { rows.eachWhile(f) }
  override Int size() { rows.size }
  override Row get(Int index) { rows[index] }
  override Row? getSafe(Int index) { rows.getSafe(index) }
  override Row? first() { rows.first }
  override Row[] toRows() { rows }
}

@Js
internal const class GbCol : Col
{
  new make(Int i, Str n, Dict m) { index = i; name = n; meta = m }
  const Int index
  const override Str name
  const override Dict meta
}

@Js
internal const class GbRow : Row
{
  new make(AtomicRef r, Obj?[] c) { gridRef = r; cells = c }
  const AtomicRef gridRef
  override const Obj?[]? cells
  override Grid grid() { gridRef.val }
  override Obj? val(Col col) { cells[((GbCol)col).index] }
}

