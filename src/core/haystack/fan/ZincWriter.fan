//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   07 Oct 2009  Brian Frank  Creation
//   28 Dec 2009  Brian Frank  DataWriter => ZincWriter
//

using xeto

**
** Write Haystack data in [Zinc]`docHaystack::Zinc` format.
**
@Js
class ZincWriter : GridWriter
{

//////////////////////////////////////////////////////////////////////////
// Convenience
//////////////////////////////////////////////////////////////////////////

  **
  ** Format a grid to a zinc string in memory.
  **
  static Str gridToStr(Grid grid)
  {
    buf := StrBuf()
    ZincWriter(buf.out).writeGrid(grid)
    return buf.toStr
  }

  **
  ** Get a value as a zinc string.
  **
  static Str valToStr(Obj? val)
  {
    buf := StrBuf()
    ZincWriter(buf.out).writeVal(val)
    return buf.toStr
  }

  **
  ** Format a set of tags to a string in memory which can be parsed with
  ** `ZincReader.readTags`.  The tags can be a 'Dict' or a 'Str:Obj' map.
  ** This method is only available for legacy purposes.  Newer code should
  ** use valToStr.
  **
  @NoDoc static Str tagsToStr(Obj tags)
  {
    buf := StrBuf()
    func := |Obj? val, Str name|
    {
      if (!buf.isEmpty) buf.addChar(' ')
      buf.add(name)
      try
        if (val !== Marker.val) buf.addChar(':').add(valToStr(val))
      catch (Err e)
        throw IOErr("Cannot write tag $name; $e.msg")
    }
    if (tags is Dict) ((Dict)tags).each(func)
    else ((Map)tags).each(func)
    return buf.toStr
  }

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Wrap given output strea
  new make(OutStream out) { this.out = out }

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  ** Write a zinc value
  Void writeVal(Obj? val)
  {
    if (val == null) return out.print("N")
    if (val is Grid) return writeNestedGrid(val)
    if (val is List) return writeList(val)
    if (val is Dict) return writeDict(val)
    writeScalar(val)
  }

  ** Write a grid to stream
  override This writeGrid(Grid grid)
  {
    // set meta-data line
    out.print("ver:\"").print(ver).print(".0\"")
    writeMeta(true, grid.meta)
    out.writeChar('\n')

    // columns lines
    if (grid.cols.isEmpty)
    {
      // technicially this should be illegal, but
      // for robustness handle it here
      out.print("noCols\n")
    }
    else
    {
      grid.cols.each |col, i|
      {
        if (i > 0) out.writeChar(',')
        writeCol(col)
      }
      out.writeChar('\n')
    }

    // rows
    grid.each |row| { writeRow(row) }
    out.writeChar('\n')
    return this
  }

  ** Write a list of grids to stream separated by newline
  @NoDoc This writeGrids(Grid[] grids)
  {
    // this is old 2.1 construct
    grids.each |grid| { writeGrid(grid) }
    return this
  }

  ** Flush underlying stream
  This flush() { out.flush; return this }

  ** Close underlying stream
  This close() { out.close; return this }

//////////////////////////////////////////////////////////////////////////
// Helpers
//////////////////////////////////////////////////////////////////////////

  private Void writeCol(Col col)
  {
    out.print(col.name)
    writeMeta(true, col.meta)
  }

  private Void writeRow(Row row)
  {
    row.grid.cols.each |col, i|
    {
      if (i > 0) out.writeChar(',')
      val := row.val(col)
      try
      {
        if (val == null)
        {
          // if this is only column, then use explicit N for null
          if (i == 0 && row.grid.cols.size == 1) out.writeChar('N')
        }
        else
        {
          writeVal(val)
        }
      }
      catch (Err e)
      {
        throw IOErr("Cannot write col '$col.name' = '$val'; $e.msg")
      }
    }
    out.writeChar('\n')
  }

  private Void writeMeta(Bool leadingSpace, Dict m)
  {
    m.each |v, k|
    {
      if (leadingSpace) out.print(" ")
      else leadingSpace = true
      out.print(k)
      try
        if (v != Marker.val) { out.print(":"); writeVal(v) }
      catch (Err e)
        throw IOErr("Cannot write meta $k: $v", e)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Values
//////////////////////////////////////////////////////////////////////////

  private Void writeNestedGrid(Grid grid)
  {
    out.writeChar('<').writeChar('<').writeChar('\n')
    writeGrid(grid)
    out.writeChar('>').writeChar('>')
  }

  private Void writeList(Obj?[] list)
  {
    out.writeChar('[')
    list.each |val, i|
    {
      if (i > 0) out.writeChar(',')
      writeVal(val)
    }
    out.writeChar(']')
  }

  private Void writeDict(Dict dict)
  {
    out.writeChar('{')
    writeMeta(false, dict)
    out.writeChar('}')
  }

  private Void writeScalar(Obj val)
  {
    kind := Kind.fromVal(val, false)
    if (kind != null)
      out.print(kind.valToZinc(val))
    else
      out.print(XStr.encode(val).toStr)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  @NoDoc Int ver := 3
  private OutStream out
}

