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
    make(Etc.emptyGrid, ShellViewType.table, Dict[,])
  }

  ** Construct state for a server error
  static ShellState makeErr(Grid errGrid)
  {
    make(errGrid, ShellViewType.table, Dict[,])
  }

  ** Constructor
  new make(Grid grid, ShellViewType viewType, Dict[] selection)
  {
    this.grid      = grid
    this.viewType  = viewType
    this.selection = selection
  }

  ** Current grid we are viewing
  const Grid grid

  ** View type for the grid (table, zinc, trio, etc)
  const ShellViewType viewType

  ** Current selected rows from the grid
  const Dict[] selection

  ** Update the grid and fallback to table view
  This setGrid(Grid g) { make(g, ShellViewType.table, Dict[,]) }

  ** Update the view type
  This setViewType(ShellViewType t) { make(grid, t, Dict[,]) }

  ** Update the selection
  This setSelection(Dict[] sel) { make(grid, viewType, sel) }
}