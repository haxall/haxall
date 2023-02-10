//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Dec 2009  Brian Frank  Creation
//

**
** Row of a Grid.  Row also implements the Dict mixin to
** expose all of the columns as name/value pairs.
**
@Js
abstract const class Row : Dict
{
  **
  ** Parent  grid
  **
  abstract Grid grid()

  **
  ** Scalar value for the cell
  **
  abstract Obj? val(Col col)

  **
  ** Get display string for dict or the given tag.  The Row
  ** implementation follows all the same rules as `Dict.dis`
  ** with following enhancements:
  **
  ** If the column meta defines a "format" pattern, then it
  ** is used to format the value via the appropiate 'toLocale'
  ** method.
  **
  override Str? dis(Str? name := null, Str? def := "")
  {
    // if name is null
    if (name == null) return Etc.dictToDis(this, def)

    // find the column, if not found return def
    col := grid.col(name, false)
    if (col == null) return def

    // get the value, if null return the def
    val := this.val(col)
    if (val == null) return def

    // fallback to Kind to get a suitable default display value
    kind := Kind.fromType(val.typeof, false)
    if (kind != null) return kind.valToDis(val, col.meta)

    // nested grid
    if (val is Grid) return "<<Nested Grid>>"

    return val.toStr
  }

//////////////////////////////////////////////////////////////////////////
// Dict
//////////////////////////////////////////////////////////////////////////

  **
  ** Always returns false.
  **
  override Bool isEmpty() { false }

  **
  ** Get the column `val` by name.  If column name doesn't
  ** exist or if the column value is null, then return 'def'.
  **
  @Operator
  override Obj? get(Str name, Obj? def := null)
  {
    col := grid.col(name, false)
    if (col == null) return def
    return val(col) ?: def
  }

  **
  ** Get the column `val` by name.  If column name doesn't exist
  ** or if the column value is null, then throw UnknownNameErr.
  **
  override Obj? trap(Str name, Obj?[]? args := null)
  {
    v := val(grid.col(name))
    if (v != null) return v
    throw UnknownNameErr(name)
  }

  **
  ** Return true if the given name is mapped to a non-null column `val`.
  **
  override Bool has(Str name)
  {
    get(name) != null
  }

  **
  ** Return true if the given name is not mapped to a non-null column `val`.
  **
  override Bool missing(Str name)
  {
    get(name) == null
  }

  **
  ** Iterate through all the columns.
  **
  override Void each(|Obj val, Str name| f)
  {
    grid.cols.each |col|
    {
      val := val(col)
      if (val != null) f(val, col.name)
    }
  }

  **
  ** Iterate through all the columns  until function returns null,
  ** then break iteration and return the result.
  **
  override Obj? eachWhile(|Obj val, Str name->Obj?| f)
  {
    grid.cols.eachWhile |col|
    {
      val := val(col)
      if (val == null) return null
      return f(val, col.name)
    }
  }

  **
  ** Raw access to cells
  **
  @NoDoc virtual Obj?[]? cells() { null }
}

