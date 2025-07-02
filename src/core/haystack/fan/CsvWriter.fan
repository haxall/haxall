//
// Copyright (c) 2011, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Apr 2011  Brian Frank  Creation
//

using util
using xeto

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
  new make(OutStream out, Dict? opts := null)
  {
    this.out = CsvOutStream(out)
    if (opts != null)
    {
      this.delimiter  = toDelimiter(opts)
      this.showHeader = toShowHeader(opts)
      this.stripUnits = toStripUnits(opts)
    }
  }

  private Int toDelimiter(Dict opts)
  {
    x := opts["delimiter"] as Str
    if (x != null && !x.isEmpty) return x[0]
    return this.delimiter
  }

  private Bool toShowHeader(Dict opts)
  {
    x := opts["showHeader"]
    if (x != null)
    {
      if (x == true || x == "true") return true
      if (x == false || x == "false") return false
    }
    return this.showHeader
  }

  private Bool toStripUnits(Dict opts)
  {
    x := opts["stripUnits"]
    if (x != null)
    {
      if (x == true || x == "true") return true
      if (x == false || x == "false") return false
    }
    return this.stripUnits
  }

//////////////////////////////////////////////////////////////////////////
// Configuration
//////////////////////////////////////////////////////////////////////////

  ** Delimiter character; defaults to comma.
  Int delimiter := ','

  ** Newline string; defaults to "\n"
  Str newline := "\n"

  ** Include the column names as a header row
  Bool showHeader := true

  ** Strip units from all numbers
  Bool stripUnits := false

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  ** Format a grid to a string in memory.
  @NoDoc static Str gridToStr(Grid grid)
  {
    buf := StrBuf()
    CsvWriter(buf.out).writeGrid(grid)
    return buf.toStr
  }

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

    // if number
    if (val is Number)
    {
      if (stripUnits) val = Number(((Number)val).toFloat, null)
    }

    // if value is Ref, is "@id dis"
    else if (val is Ref)
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

