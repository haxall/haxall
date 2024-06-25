//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Dec 2009  Brian Frank  Creation
//

**
** Two dimensional tabular data structure composed of Cols and Rows.
** Grids may be created by factory methods on `Etc` or using `GridBuilder`.
** See [docHaystack]`docHaystack::Kinds#grid`.
**
@Js
const mixin Grid
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  **
  ** Columns
  **
  abstract Col[] cols()

  **
  ** Get a column by its name.  If not resolved then
  ** return null or throw UnknownNameErr based on checked flag.
  **
  abstract Col? col(Str name, Bool checked := true)

  **
  ** Convenience for `cols` mapped to `Col.name`.  The
  ** resulting list is safe for mutating.
  **
  Str[] colNames() { cols.map |col->Str| { col.name } }

  **
  ** Convenience for `cols` mapped to `Col.dis`.  The
  ** resulting list is safe for mutating.
  **
  Str[] colDisNames() { cols.map |col->Str| { col.dis } }

  **
  ** Return if this grid contains the given column name.
  **
  Bool has(Str name) { col(name, false) != null }

  **
  ** Return if this grid does not contains the given column name.
  **
  Bool missing(Str name) { col(name, false) == null }

  **
  ** Iterate the rows
  **
  abstract Void each(|Row row, Int index| f)

  **
  ** Iterate every row until the function returns non-null.  If
  ** function returns non-null, then break the iteration and return
  ** the resulting object.  Return null if the function returns
  ** null for every item
  **
  abstract Obj? eachWhile(|Row row, Int index->Obj?| f)

  **
  ** Convenience for `size` equal to zero.
  **
  Bool isEmpty() { size == 0 }

  **
  ** Return if this is an error grid - meta has "err" tag.
  **
  Bool isErr() { meta.has("err") }

  **
  ** Return if this grid indicates incomplete data
  **
  @NoDoc Bool isIncomplete()
  {
    meta.has("incomplete") || meta.has("more")
  }

  **
  ** Get meta about incomplete
  **
  @NoDoc Dict? incomplete(Bool checked := true)
  {
    val := meta["incomplete"]
    if (val == null && meta.has("more"))
    {
      val = Etc.emptyDict
      if (meta.has("limit")) val = Etc.makeDict1("dis", "Limit exceeded: " + this.meta["limit"])
    }
    if (val == null)
    {
      if (checked) throw UnknownNameErr("incomplete")
      return null
    }
    return val as Dict ?: Etc.emptyDict
  }

  **
  ** Return if this grid conforms to the [history grid shape]`lib-his::doc#hisGrid`:
  **  - has at least two columns
  **  - first column is named "ts"
  **  - has meta hisStart and hisEnd DateTime values
  **
  ** This method does **not** check timezones or the ts cells.
  **
  Bool isHisGrid()
  {
    cols.size >= 2 &&
    cols[0].name == "ts" &&
    meta["hisStart"] is DateTime &&
    meta["hisEnd"] is DateTime
  }

  **
  ** Get the number of rows in the grid.  Throw UnsupportedErr
  ** if the grid doesn't support a size.
  **
  abstract Int size()

  **
  ** Get the first row or return null if grid is empty.
  **
  abstract Row? first()

  **
  ** Get the last row or return null if grid is empty.
  ** Throw UnsupportedErr is the grid doesn't support indexed
  ** based row access.
  **
  virtual Row? last() { isEmpty ? null : get(-1) }

  **
  ** Get a row by its index number.  Throw UnsupportedErr is
  ** the grid doesn't support indexed based row access.
  **
  @Operator
  abstract Row get(Int index)

  **
  ** Get a row by its index number or if index is out of bounds
  ** then return null.  Throw UnsupportedErr is the grid doesn't
  ** support indexed based row access.
  **
  abstract Row? getSafe(Int index)

  **
  ** Meta-data for entire grid
  **
  abstract Dict meta()

  **
  ** Legacy hook to force lazily loaded grids into memory.
  **
  @NoDoc
  virtual Grid toConst() { this }

//////////////////////////////////////////////////////////////////////////
// Transformations
//////////////////////////////////////////////////////////////////////////

  **
  ** Return true if the function returns true for any of the
  ** rows in the grid.  If the grid is empty, return false.
  **
  Bool any(|Row item, Int index->Bool| f)
  {
    r := eachWhile |item, i|
    {
      f(item, i) ? "hit" : null
    }
    return r != null ? true : false
  }

  **
  ** Return true if the function returns true for all of the
  ** rows in the grid.  If the grid is empty, return false.
  **
  Bool all(|Row item, Int index->Bool| f)
  {
    r := eachWhile |item, i|
    {
      f(item, i) ? null : "miss"
    }
    return r == null ? true : false
  }

  **
  ** Return a new Grid which is a copy of this grid with
  ** the rows sorted by the given comparator function.
  **
  Grid sort(|Row a, Row b->Int| f)
  {
    if (isEmpty) return this
    gb := GridBuilder().copyMetaAndCols(this)
    rows := toRows.dup.sort(f)
    return gb.addDictRows(rows).toGrid
  }

  **
  ** Return a new Grid which is a copy of this grid with
  ** the rows reverse sorted by the given comparator function.
  **
  Grid sortr(|Row a, Row b->Int| f)
  {
    if (isEmpty) return this
    gb := GridBuilder().copyMetaAndCols(this)
    rows := toRows.dup.sortr(f)
    return gb.addDictRows(rows).toGrid
  }

  **
  ** Convenience for `sort` which sorts the given column.
  ** The 'col' parameter can be a `Col` or a str name.  The sorting
  ** algorithm used is the same one used by the table UI based on
  ** the localized display string.  If column is not found then
  ** return this.
  **
  Grid sortCol(Obj col)
  {
    if (isEmpty) return this
    c := toCol(col, false)
    if (c == null) return this
    return sort |a, b| { Etc.sortCompare(a.val(c), b.val(c)) }
  }

  **
  ** Sort the given column in reverse.  See `sortCol`
  **
  Grid sortColr(Obj col)
  {
    if (isEmpty) return this
    c := toCol(col, false)
    if (c == null) return this
    return sortr |a, b| { Etc.sortCompare(a.val(c), b.val(c)) }
  }

  **
  ** Sort using `Etc.compareDis` and `Dict.dis`.
  **
  Grid sortDis()
  {
    try
      return sort |a, b| { Etc.compareDis(a.dis, b.dis) }
    catch (Err e)
      return sort |a, b| { a.dis <=> b.dis }
  }

  **
  ** Extract 'id' column to list of Refs
  **
  @NoDoc Ref[] ids()
  {
    colToList("id", Ref#)
  }

  **
  ** Get a column as a list of the cell values ordered by row.
  **
  Obj?[] colToList(Obj col, Type listOf := Obj?#)
  {
    c := toCol(col)
    capacity := 16
    try capacity = size; catch (Err e) {}
    Obj?[] acc := List.make(listOf, capacity)
    each |row| { acc.add(row.val(c)) }
    return acc
  }

  **
  ** Find one matching row or return null if no matches.
  ** Also see `findIndex` and `findAll`.
  **
  Row? find(|Row, Int index->Bool| f)
  {
    eachWhile |row, i| { f(row, i) ? row : null }
  }

  **
  ** Find one matching row index or return null if no matches.
  ** Also see `find`.
  **
  Int? findIndex(|Row, Int index->Bool| f)
  {
    eachWhile |row, i| { f(row, i) ? i : null }
  }

  **
  ** Return a new grid which finds matching the rows in this
  ** grid.  The has the same meta and column definitions.
  ** Also see `find` and `filter`.
  **
  Grid findAll(|Row, Int index->Bool| f)
  {
    gb := GridBuilder().copyMetaAndCols(this)
    rows := toRows.findAll(f)
    return gb.addDictRows(rows).toGrid
  }

  **
  ** Return a new grid which finds matching rows based
  ** on the given filter.  Also see `findAll`.
  **
  Grid filter(Filter filter, HaystackContext? cx := null)
  {
    findAll |row| { filter.matches(row, cx) }
  }

  **
  ** Return a new grid which is a slice of the rows in
  ** this grid.  Negative indexes may be used to access
  ** from the end of the grid.  The has the same meta
  ** and column definitions.
  **
  @Operator
  Grid getRange(Range r)
  {
    gb := GridBuilder().copyMetaAndCols(this)
    rows := toRows.getRange(r)
    return gb.addDictRows(rows).toGrid
  }

  **
  ** Return a new grid which maps the rows to new Dict.  The grid
  ** meta and existing column meta are maintained.  New columns
  ** have empty meta.  If the mapping function returns null, then
  ** the row is removed.
  **
  Grid map(|Row, Int index->Obj?| f)
  {
    // perform map
    newRows := Dict[,]
    colNames := Str[,]
    colNamesMap := Str:Str[:]
    numRows := 0
    each |row, i|
    {
      // call func
      numRows++
      newVal := f(row, i)

      // null skips/removes row
      if (newVal == null) return

      // if Dict wasn't provided raise meaningful error message
      newRow := newVal as Dict
      if (newRow == null) throw Err("Grid.map expects Dict, not $newVal.typeof.name")

      newRows.add(newRow)
      Etc.dictEach(newRow) |v, n|
      {
        if (colNamesMap[n] == null) { colNames.add(n); colNamesMap[n] = n }
      }
    }

    // short circuit if this grid was empty
    if (numRows == 0) return this

    // build new grid
    gb := GridBuilder().setMeta(meta)
    colNames.each |n|
    {
      old := col(n, false)
      gb.addCol(n, old?.meta)
    }
    return gb.addDictRows(newRows).toGrid
  }

  **
  ** Return a new grid which maps each of the rows to zero or more new Dicts.
  ** The grid meta and existing column meta are maintained.  New columns
  ** have empty meta.
  **
  Grid flatMap(|Row, Int index->Obj?| f)
  {
    // perform map
    newRows := Dict[,]
    colNames := Str[,]
    colNamesMap := Str:Str[:]
    numRows := 0
    each |row, i|
    {
      // call func
      numRows++
      mapVals := f(row, i)

      // null skips/removes row
      if (mapVals == null) return

      // if List of Dicts wasn't provided raise meaningful error message
      mapRows := mapVals as List
      if (mapRows == null) throw Err("Grid.flatMap expects Dict[], not $mapVals.typeof.name")

      mapRows.each |mapVal, j|
      {
        if (mapVal == null) return
        mapRow := mapVal as Dict
        if (mapRow == null) throw Err("Grid.flatMap expects Dict[] (item $j: $mapVal.typeof.name)")

        newRows.add(mapRow)
        mapRow.each |v, n|
        {
          if (colNamesMap[n] == null) { colNames.add(n); colNamesMap[n] = n }
        }
      }
    }

    // short circuit if this grid was empty
    if (numRows == 0) return this

    // build new grid
    gb := GridBuilder().setMeta(meta)
    colNames.each |n|
    {
      old := col(n, false)
      gb.addCol(n, old?.meta)
    }
    return gb.addDictRows(newRows).toGrid
  }

  ** Map each row to a list of values.
  @NoDoc Obj?[] mapToList(|Row,Int->Obj?| f)
  {
    Obj?[] list := List.make(f.returns, size)
    each |row, i| { list.add(f(row, i)) }
    return list
  }

  **
  ** Return a new Grid which is the result of applying the given
  ** diffs to this grid.  The diffs must have the same number of
  ** rows as this grid. Any cells in the diffs with a Remove.val
  ** are removed from this grid, otherwise they are updated/added.
  **
  Grid commit(Grid diffs)
  {
    // check sizes
    if (diffs.size != this.size) throw ArgErr("diff.size doesn't match")
    i := 0
    return map |old|
    {
      diff := diffs[i++]
      x := Str:Obj?[:]
      x.ordered = true
      old.each |v, n| { x[n] = v }
      diff.each |v, n| { if (v == Remove.val) x.remove(n); else x[n] = v }
      return Etc.makeDict(x)
    }
  }

  **
  ** Join two grids by column name.  The 'joinCol' parameter may
  ** be a `Col` or col name.  Current implementation requires:
  **  - grids cannot have conflicting col names (other than join col)
  **  - each row in both grids must have a unique value for join col
  **  - grid level meta is merged
  **  - join column meta is merged
  **
  Grid join(Grid that, Obj joinCol)
  {
    // get col references
    a := this;  aJoinCol := a.toCol(joinCol)
    b := that;  bJoinCol := b.toCol(joinCol)

    // get join set of columns
    cols := Col[,]
    a.cols.each |c|
    {
      meta := c.meta
      if (c === aJoinCol)
      {
        meta = Etc.dictMerge(meta, bJoinCol.meta)
      }
      cols.add(GbCol(-1, c.name, meta))
    }
    b.cols.each |c|
    {
      if (c === bJoinCol) return
      n := c.name
      if (a.has(n)) throw Err("Join column name conflict $n")
       cols.add(GbCol(-1, c.name, c.meta))
    }

    // map b to hashmap by join col
    bRows := Obj:Row[:] { ordered = true }
    b.each |r| { bRows.add(r.val(bJoinCol), r) }

    // now created merged rows
    gb := GridBuilder().setMeta(Etc.dictMerge(a.meta, b.meta))
    cols.each |c| { gb.addCol(c.name, c.meta) }
    a.each |r|
    {
      cells := Obj?[,]
      a.cols.each |c| { cells.add(r.val(c)) }
      bRow := bRows.remove(r.val(aJoinCol))
      b.cols.each |c|
      {
        if (c === bJoinCol) return
        if (bRow == null) cells.add(null)
        else cells.add(bRow.val(c))
      }
      gb.addRow(cells)
    }

    // any rows left over in thatRows are ones missing from this
    bRows.each |r|
    {
      cells := Obj?[,]
      a.cols.each |c|
      {
        if (c === aJoinCol) cells.add(r.val(bJoinCol))
        else cells.add(null)
      }
      b.cols.each |c|
      {
        if (c !== bJoinCol) cells.add(r.val(c))
      }
      gb.addRow(cells)
    }

    return gb.toGrid
  }

  **
  ** Return a new grid with grid level meta-data replaced by given
  ** meta.  The meta may be any value accepted by `Etc.makeDict`.
  ** Also see `addMeta`.
  **
  Grid setMeta(Obj? meta)
  {
    gb := GridBuilder().copyCols(this)
    gb.setMeta(Etc.makeDict(meta))
    return gb.addGridRows(this).toGrid
  }

  **
  ** Return a new grid with additional grid level meta-data.
  ** The new tags are merged according to `Etc.dictMerge`.
  ** The meta may be any value accepted by `Etc.makeDict`
  ** Also see `setMeta`.
  **
  Grid addMeta(Obj? meta)
  {
    gb := GridBuilder().copyCols(this)
    gb.setMeta(Etc.dictMerge(this.meta, meta))
    return gb.addGridRows(this).toGrid
  }

  **
  ** Return a new grid with an additional column.  The cells of the
  ** column are created by calling the mapping function for each row.
  ** The meta may be any value accepted by `Etc.makeDict`
  **
  Grid addCol(Str name, Obj? meta, |Row, Int->Obj?| f)
  {
    gb := GridBuilder().setMeta(this.meta)
    this.cols.each |c| { gb.addCol(c.name, c.meta) }
    gb.addCol(name, meta)
    each |r, i|
    {
      cells := Obj?[,]
      cells.capacity = gb.numCols
      this.cols.each |c| { cells.add(r.val(c)) }
      cells.add(f(r, i))
      gb.addRow(cells)
    }
    return gb.toGrid
  }

  **
  ** Return a new grid by adding the given grid as a new set of columns
  ** to this grid.  If the given grid contains duplicate column names, then
  ** they are given auto-generated unique names.  If the given grid contains
  ** fewer rows then this grid, then the missing cells are filled with null.
  **
  Grid addCols(Grid x)
  {
    a := this; aCols := a.cols
    b := x;    bCols := b.cols

    newCols := GridBuilder.normColNames(a.colNames.dup.addAll(b.colNames))
    newRows := Obj?[][,]
    try { newRows.capacity = a.size } catch (Err e) {}

    a.each |aRow, i|
    {
      newRow := Obj?[,]
      newRow.size = newCols.size
      aCols.each |c, j| { newRow[j] = aRow.val(c) }
      newRows.add(newRow)
    }

    b.each |bRow, i|
    {
      newRow := newRows.getSafe(i)
      if (newRow == null) return
      bCols.each |c, j| { newRow[aCols.size+j] = bRow.val(c) }
    }

    gb := GridBuilder().setMeta(a.meta)
    gb.capacity = newRows.size
    aCols.each |c, j| { gb.addCol(c.name, c.meta) }
    bCols.each |c, j| { gb.addCol(newCols[aCols.size+j], c.meta) }
    newRows.each |row| { gb.addRow(row) }
    return gb.toGrid
  }

  **
  ** Return a new grid with the given column renamed.
  ** The 'oldCol' parameter may be a `Col` or col name.
  **
  Grid renameCol(Obj oldCol, Str newName)
  {
    x := toCol(oldCol)
    gb := GridBuilder().setMeta(this.meta)
    cols := this.cols
    cols.each |c|
    {
      if (c !== x) gb.addCol(c.name, c.meta)
      else gb.addCol(newName, c.meta)
    }
    each |r, i|
    {
      cells := Obj?[,]
      cells.capacity = gb.numCols
      cols.each |c| { cells.add(r.val(c)) }
      gb.addRow(cells)
    }
    return gb.toGrid
  }

  **
  ** Return a new grid with multiple columns renamed.  The
  ** given map is keyed old column names and maps to new
  ** column names.  Any column names not found are ignored.
  **
  Grid renameCols(Obj:Str oldToNew)
  {
    if (oldToNew.isEmpty) return this

    map := Str:Str[:]
    oldToNew.each |n, o|
    {
      c := toCol(o, false)
      if (c != null) map[c.name] = n
    }

    gb := GridBuilder().setMeta(this.meta)
    cols := this.cols
    cols.each |c|
    {
      newName := map[c.name] ?: c.name
      gb.addCol(newName, c.meta)
    }
    each |r, i|
    {
      cells := Obj?[,]
      cells.capacity = gb.numCols
      cols.each |c| { cells.add(r.val(c)) }
      gb.addRow(cells)
    }
    return gb.toGrid
  }

  **
  ** Return a new grid with the columns reordered.  The
  ** given list of names represents the new order and must
  ** contain the same current `Col` instances or column names.
  ** Any column names not found are ignored.
  **
  Grid reorderCols(Obj[] cols)
  {
    gb := GridBuilder().setMeta(this.meta)
    newOrder := Col[,]
    newOrder.capacity = cols.size
    cols.each |col|
    {
      c := toCol(col, false)
      if (c == null) return
      newOrder.add(c)
      gb.addCol(c.name, c.meta)
    }
    each |r, i|
    {
      cells := Obj?[,]
      cells.capacity = gb.numCols
      newOrder.each |c| { cells.add(r.val(c)) }
      gb.addRow(cells)
    }
    return gb.toGrid
  }

  **
  ** Return new grid with column meta-data replaced by given meta.
  ** The 'col' parameter may be either a `Col` or column name.
  ** The meta may be any value accepted by `Etc.makeDict`
  ** If column is not found then return this.  Also see `addColMeta`.
  **
  Grid setColMeta(Obj col, Obj? meta)
  {
    c := toCol(col, false)
    if (c == null) return this
    gb := GridBuilder().copyMetaAndCols(this)
    gb.setColMeta(c.name, Etc.makeDict(meta))
    return gb.addGridRows(this).toGrid
  }

  **
  ** Return a new grid with additional column meta-data.
  ** The new tags are merged according to `Etc.dictMerge`.
  ** The 'col' parameter may be either a `Col` or column name.
  ** The meta may be any value accepted by `Etc.makeDict`.
  ** If column is not found then return this. Also see `setColMeta`.
  **
  Grid addColMeta(Obj col, Obj? meta)
  {
    c := toCol(col, false)
    if (c == null) return this
    gb := GridBuilder().copyMetaAndCols(this)
    gb.setColMeta(c.name, Etc.dictMerge(c.meta, meta))
    return gb.addGridRows(this).toGrid
  }

  **
  ** Return a new grid with the given column removed.
  ** The 'col' parameter may be either a `Col` or column name.
  ** If column doesn't exist return this grid.
  **
  Grid removeCol(Obj col)
  {
    x := toCol(col, false)
    if (x == null) return this
    gb := GridBuilder().setMeta(this.meta)
    cols := this.cols
    cols.each |c| { if (c !== x) gb.addCol(c.name, c.meta) }
    each |r, i|
    {
      cells := Obj?[,]
      cells.capacity = gb.numCols
      cols.each |c| { if (c !== x) cells.add(r.val(c)) }
      gb.addRow(cells)
    }
    return gb.toGrid
  }

  **
  ** Return a new grid with all the columns removed except
  ** the given columns.  The 'toKeep' columns can be `Col`
  ** instances or column names.  Columns not found are silently
  ** ignored.
  **
  Grid keepCols(Obj[] toKeep)
  {
    toKeepNames := Str:Col[:]
    toKeep.each |x| { c := toCol(x, false); if (c != null) toKeepNames[c.name] = c }

    toRemove := Col[,]
    cols.each |c|{ if (toKeepNames[c.name] == null) toRemove.add(c) }

    return removeCols(toRemove)
  }

  **
  ** Return a new grid with all the given columns removed.
  ** The 'toRemove' columns can be `Col` instances or column names.
  ** Columns not found are silently ignored.
  **
  Grid removeCols(Obj[] toRemove)
  {
    if (toRemove.isEmpty) return this

    // map columns to remove hash map of column names
    x := Str:Col[:]
    toRemove.each |col|
    {
      c := toCol(col, false)
      if (c != null) x[c.name] = c
    }
    if (x.isEmpty) return this

    // rebuild
    gb := GridBuilder().setMeta(this.meta)
    cols := this.cols
    cols.each |c| { if (!x.containsKey(c.name)) gb.addCol(c.name, c.meta) }
    each |r, i|
    {
      cells := Obj?[,]
      cells.capacity = gb.numCols
      cols.each |c| { if (!x.containsKey(c.name)) cells.add(r.val(c)) }
      gb.addRow(cells)
    }
    return gb.toGrid
  }

  **
  ** Return a new Grid wich each col name mapped to its localized
  ** tag name if the col does not already have a display string.
  ** See `Etc.tagToLocale` and `docSkySpark::Localization#tags`.
  **
  Grid colsToLocale()
  {
    gb := GridBuilder().setMeta(this.meta)
    cols.each |c|
    {
      meta := c.meta
      if (meta.missing("dis"))
        meta = Etc.dictSet(meta, "dis", Etc.tagToLocale(c.name))
      gb.addCol(c.name, meta)
    }
    return gb.addGridRows(this).toGrid
  }

  **
  ** Return a new grid with only rows that define a unique key
  ** by the given key columns.  If multiple rows have the same
  ** key cells, then the first row is returned and subsequent
  ** rows are removed.  The 'keyCols' can be `Col` instances or
  ** column names.
  **
  Grid unique(Obj[] keyCols)
  {
    cols := toCols(keyCols)
    seen := Obj:Str[:]
    return findAll |row|
    {
      key := Obj?[,]
      key.capacity = cols.size
      cols.each |col|
      {
        key.add(row.get(col.name))
      }
      key = key.toImmutable
      if (seen[key] != null) return false
      seen[key] = "seen"
      return true
    }
  }

  **
  ** Perform a matrix transpose on the grid.  The cells of the
  ** first column because the display names for the new columns.
  ** Columns 1..n become the new rows.
  **
  @NoDoc virtual Grid transpose()
  {
    // first column cells become the new column names
    srcKeyCol := this.cols.first
    srcTransposedDis := srcKeyCol.meta["transposedDis"] as Str

    // initialize grid
    gb := GridBuilder()
    gb.setMeta(this.meta)
    if (srcTransposedDis == null)
      gb.addCol("dis", ["transposedDis":srcKeyCol.dis])
    else
      gb.addCol("dis", ["dis":srcTransposedDis])

    // first cell of each row becomes column display name
    this.each |row, i|
    {
      name := "v" + i
      dis := row.dis(srcKeyCol.name, name)
      gb.addCol(name, ["dis":dis])
    }

    // columns becomes rows
    this.cols.each |col, i|
    {
      if (i == 0) return
      row := Obj?[,]
      row.capacity = gb.numCols
      row.add(col.dis)
      this.each |srcRow| { row.add(srcRow.val(col)) }
      gb.addRow(row)
    }

    return gb.toGrid
  }

  **
  ** Internal utility to map Obj[] to Col[]
  **
  internal Col[] toCols(Obj[] cols)
  {
    cols.map |x| { toCol(x) }
  }

  **
  ** Internal utility to map Obj to Col
  **
  internal Col? toCol(Obj c, Bool checked := true)
  {
    if (c is Str) return col(c, checked)
    if (c is Col) return col(((Col)c).name, checked)
    throw ArgErr("Expected Col or Str col name, not '$c.typeof'")
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  **
  ** Get all the rows as a in-memory list.  We don't expose this
  ** as public method because most code should be using iteration via each.
  **
  @NoDoc abstract Row[] toRows()

  **
  ** Debug dump with some pretty print - no guarantee regarding format.
  ** Options:
  **   - noClip: true to not clip the columns
  **
  @NoDoc Void dump(OutStream out := Env.cur.out, [Str:Obj]? opts := null)
  {
    dumpMeta(out, "Grid:", meta)
    cols.each |col| { dumpMeta(out, "$col.name \"$col.dis\":", col.meta) }

    lines := Str[,].fill("", 2+size)
    cols.each |c| { dumpAddCol(this, c, lines) }

    // optionally clip
    if (opts == null || opts["noClip"] != true)
      lines = lines.map |line| { line.size <= 125 ? line : line[0..125] + "..." }

    lines.each |line| { out.printLine(line) }
  }

  private static Void dumpMeta(OutStream out, Str title, Dict meta)
  {
    if (meta.isEmpty) return
    out.printLine(title)
    Etc.dictNames(meta).sort.each |n|
    {
      out.printLine(" $n: " + meta[n])
    }
  }

  private static Void dumpAddCol(Grid g, Col c, Str[] lines)
  {
    dips := Str[,]
    g.each |r| { dips.add(toDis(r, c)) }

    width := c.name.size
    dips.each |d| { width = width.max(d.size) }
    sep := lines.first.isEmpty ? "" : "  "

    i := 0
    lines[i] += sep + c.name.padr(width); i++
    lines[i] += sep + Str.spaces(width).replace(" ", "-"); i++
    dips.each |d| { lines[i] += sep + d.padr(width); i++ }
  }

  private static Str toDis(Row r, Col c)
  {
    val := r.val(c)
    if (val === Marker.val) return "M"
    if (val === Remove.val) return "R"
    if (val is DateTime && c.meta["format"] == null) return ((DateTime)val).toLocale("DD-MMM-YY hh:mm")
    s := r.dis(c.name)
    return s
  }
}

