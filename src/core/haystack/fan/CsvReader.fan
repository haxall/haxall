//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Jul 2020  Brian Frank  Creation
//

using util

**
** Read Haystack data in [CSV]`docHaystack::Csv` format.
**
@Js
class CsvReader : GridReader
{

  ** Wrap input stream
  new make(InStream in)
  {
    this.in = CsvInStream(in)
  }

  ** Return CSV file as a grid.  Invalid column names are automatically
  ** converted in safe names, but the original name may be retreived
  ** from the col meta via the "orig" tag.
  override Grid readGrid()
  {
    rows := in.readAllRows
    if (rows.isEmpty) return Etc.makeEmptyGrid

    // extract column names
    origNames := rows.removeAt(0)
    colNames := GridBuilder.normColNames(origNames)

    // handle trailing empty lines
    while (!rows.isEmpty && rows.last.isEmpty) rows.removeAt(-1)

    // build as grid
    gb := GridBuilder()
    colNames.each |n, i| { gb.addCol(n, Etc.dict1("orig", origNames[i])) }
    rows.each |row, i| { gb.addRow(row) }
    return gb.toGrid
  }

  private CsvInStream in
}

