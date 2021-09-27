//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Jun 2021  Brian Frank  Creation
//

using dom
using domkit
using haystack

**
** ShellState models the variable UI state
**
@Js
internal class ShellState
{
  ** Construct initial state
  static ShellState makeInit()
  {
    make("", Etc.emptyGrid, ShellViewType.table, Dict#.emptyList)
  }

  ** Construct state for a new server result
  static ShellState makeEvalOk(Str expr, Grid grid)
  {
    make(expr, grid, ShellViewType.toBest(grid), Dict#.emptyList)
  }

  ** Construct state for a server error
  static ShellState makeEvalErr(Str expr, Grid errGrid)
  {
    make(expr, errGrid, ShellViewType.table, Dict#.emptyList)
  }

  ** Constructor
  new make(Str expr, Grid grid, ShellViewType viewType, Dict[] selection)
  {
    this.expr      = expr
    this.grid      = grid
    this.viewType  = viewType
    this.selection = selection
  }

  ** Current axon expression
  const Str expr

  ** Current grid we are viewing
  const Grid grid

  ** View type for the grid (table, zinc, trio, etc)
  const ShellViewType viewType

  ** Current selected rows from the grid
  const Dict[] selection

  ** Update the view type
  This setViewType(ShellViewType t) { make(expr, grid, t, Dict#.emptyList) }

  ** Update the selection
  This setSelection(Dict[] sel) { make(expr, grid, viewType, sel) }

}