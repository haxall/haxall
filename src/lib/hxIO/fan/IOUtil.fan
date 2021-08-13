//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 May 2016  Brian Frank  Creation
//

using util
using haystack
using axon
using hx
using folio

**
** IOUtil is used to map an object to a File for use in email attachments, etc
**
const class IOUtil
{
  ** Convert I/O handle to a file
  static File toFile(HxContext cx, Obj obj, Str debugAction)
  {
    return IOHandle.fromObj(obj).toFile(debugAction)
  }

  ** Open file as a Zip
  internal static Zip openZip(File file)
  {
    m := file.typeof.method("toLocal", false)
    if (m != null) file = m.callOn(file, Obj?[,])
    return Zip.open(file)
  }
}

**************************************************************************
** IOCsvReader
**************************************************************************

internal class IOCsvReader
{
  new make(Obj handle, Dict? opts)
  {
    this.handle    = handle
    this.opts      = opts ?: Etc.emptyDict
    this.delimiter = this.opts["delimiter"] as Str ?: ","
    this.noHeader  = this.opts.has("noHeader")
  }

  Grid read()
  {
    return IOHandle.fromObj(handle).withIn |in|
    {
      // parse rows
      rows := makeCsvInStream(in).readAllRows
      if (rows.isEmpty) return Etc.makeEmptyGrid

      // extract column names
      colNames := noHeader? genColNames(rows[0]) : normColNames(rows.removeAt(0))

      // handle trailing empty lines
      while (!rows.isEmpty && rows.last.isEmpty) rows.removeAt(-1)

      // build as grid
      gb := GridBuilder().addColNames(colNames)
      rows.each |row, i|
      {
        checkColCount(colNames, row, i)
        normRow := row.map |cell->Obj?| { normCell(cell) }
        gb.addRow(normRow)
      }
      return gb.toGrid
    }
  }

  Obj? each(Fn fn)
  {
    return IOHandle.fromObj(handle).withIn |in|
    {
      cx := HxContext.curHx
      args := [null, null]
      num := 0
      makeCsvInStream(in).eachRow |row|
      {
        fn.call(cx, args.set(0, row.toImmutable).set(1, Number(num)))
        num++
      }
      return Number(num)
    }
  }

  Void stream(IOStreamCsvStream stream)
  {
    IOHandle.fromObj(handle).withIn |inRaw|
    {
      // create stream
      in := makeCsvInStream(inRaw)

      // read first row
      firstRow := in.readRow
      if (firstRow == null) return null

      // if noHeader then this is data, otherwise our col names
      colNames := noHeader ? genColNames(firstRow) : normColNames(firstRow)
      if (noHeader) submit(stream, colNames, firstRow)

      // keep iterating as long as stream is not complete
      while (!stream.isComplete)
      {
        cells := in.readRow
        if (cells == null) break
        submit(stream, colNames, cells)
      }
      return null
    }
  }

  private Void submit(MStream stream, Str[] colNames, Str[] cells)
  {
    checkColCount(colNames, cells, submitted)
    map := Str:Obj?[:] { ordered = true }
    colNames.each |n, i| { map[n] = normCell(cells[i]) }
    dict := Etc.makeDict(map)
    stream.submit(dict)
    submitted++
  }

  private Str[] genColNames(Str[] firstRow)
  {
    firstRow.map |r,i| { "v${i}" }
  }

  private Str[] normColNames(Str[] firstRow)
  {
    GridBuilder.normColNames(firstRow)
  }

  private CsvInStream makeCsvInStream(InStream in)
  {
    CsvInStream(in) { it.delimiter = this.delimiter[0] }
  }

  private Void checkColCount(Str[] colNames, Str[] cells, Int rowIndex)
  {
    if (colNames.size == cells.size) return
    throw IOErr("Invalid number of cols in row ${rowIndex+1} (expected $colNames.size, got $cells.size)\n" + cells.join(","))
  }

  private Obj? normCell(Str cell)
  {
    cell.isEmpty ? null : cell
  }

  private Obj handle
  private const Dict opts
  private const Bool noHeader
  private const Str delimiter
  private Int submitted
}

