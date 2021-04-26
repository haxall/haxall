//
// Copyright (c) 2011, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Apr 2011  Brian Frank  Creation
//

using util

**
** Write Haystack data in [CSV]`docHaystack::Csv` format.
**
@Js
class CsvWriter : GridWriter
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Wrap output stream
  new make(OutStream out) { this.out = CsvOutStream(out) }

//////////////////////////////////////////////////////////////////////////
// Configuration
//////////////////////////////////////////////////////////////////////////

  ** Delimiter character; defaults to comma.
  Int delimiter := ','

  ** Newline string; defaults to "\n"
  Str newline := "\n"

  ** Include the column names as a header row
  Bool showHeader := true

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  ** Flush the underlying output stream and return this
  This flush() { out.flush; return this }

  ** Close the underlying output stream
  Bool close() {  out.close }

  ** Write grid as CSV and return this
  override This writeGrid(Grid grid)
  {
    // column names
    cols := grid.cols
    if (showHeader)
    {
      cols.each |col, i|
      {
        if (i > 0) out.writeChar(delimiter)
        out.writeCell(col.dis)
      }
      out.print(newline)
    }

    // rows
    grid.each |row|
    {
      cols.each |col, i|
      {
        if (i > 0) out.writeChar(delimiter)
        writeScalarCell(row, col)
      }
      out.print(newline)
    }

    out.flush
    return this
  }

  private Void writeScalarCell(Row row, Col col)
  {
    // write null as empty cell
    val := row.val(col)
    if (val == null) { out.writeChar('"').writeChar('"'); return }

    // if marker use checkmark
    if (val === Marker.val) { out.writeChar(0x2713); return }

    // if value is Ref, is "@id dois"
    if (val is Ref)
    {
      ref := (Ref)val
      if (ref.disVal == null)
        out.writeCell("@$ref.id")
      else
        out.writeCell("@$ref.id $ref.disVal")
      return
    }

    // write toStr
    out.writeCell(val.toStr)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private CsvOutStream out

}