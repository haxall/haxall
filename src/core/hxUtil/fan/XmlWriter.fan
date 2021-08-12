//
// Copyright (c) 2011, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Apr 2011  Brian Frank  Creation
//

using haystack

@NoDoc
@Js
class XmlWriter : GridWriter
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Wrap output stream
  new make(OutStream out) { this.out = out }

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  ** Flush the underlying output stream and return this
  This flush() { out.flush; return this }

  ** Close the underlying output stream
  Bool close() {  out.close }

  ** Write grid as XML and return this
  override This writeGrid(Grid grid)
  {
    out.printLine("<grid ver='3.0'>")
    writeGridBody(grid)
    out.printLine("</grid>")
    out.flush
    return this
  }

  private Void writeGridBody(Grid grid)
  {
    if (!grid.meta.isEmpty) writeMeta(grid.meta)

    cols := grid.cols
    out.printLine
    out.printLine("<cols>")
    cols.each |col| { writeCol(col) }
    out.printLine("</cols>")

    out.printLine
    grid.each |row| { writeRow(cols, row) }
  }

  private Void writeCol(Col col)
  {
    out.print("<").print(col.name)
    dis := col.dis
    meta := col.meta
    if (dis != col.name)
    {
      writeAttr("dis", dis)
      meta = Etc.dictRemove(meta, "dis")
    }
    writeMetaAndEnd(col.name, meta)
  }

  private Void writeRow(Col[] cols, Row row)
  {
    out.printLine("<row>")
    cols.each |col| { writeCell(row, col) }
    out.printLine("</row>")
  }

  private Void writeCell(Row row, Col col)
  {
    val := row.val(col)
    if (val == null) return
    writeVal(col.name, val)
  }

  private Void writeMetaAndEnd(Str elemName, Dict meta)
  {
    if (meta.isEmpty) { out.printLine("/>"); return }
    out.printLine(">")
    writeMeta(meta)
    out.print("</").print(elemName).printLine(">")
  }

  private Void writeMeta(Dict meta)
  {
    out.printLine("<meta>")
    meta.each |v, n| { writeVal(n, v) }
    out.printLine("</meta>")
  }

  private Void writeVal(Str elemName, Obj? val)
  {
    kind := Kind.fromVal(val, false)
    kindName := kind?.name ?: "null"

    out.print("<").print(elemName)
    writeAttr("kind", kindName)

    if (kind == null || !kind.isCollection)
    {
      writeValAttr(val)
      out.printLine("/>")
    }
    else if (kind.isCollection)
    {
      out.printLine(">")
      if (kind.isList) writeList(val)
      if (kind.isDict) writeDict(val)
      if (kind == Kind.grid) writeGridBody(val)
      out.print("</").print(elemName).printLine(">")
    }
  }

  private Void writeValAttr(Obj? val)
  {
    if (val == null || val === Marker.val || val === NA.val || val === Remove.val) return

    if (val is Ref)
    {
      ref := (Ref)val
      if (ref.disVal != null) writeAttr("dis", ref.disVal)
      writeAttr("val", ref.id)
      return
    }

    writeAttr("val", val.toStr)
  }

  private Void writeList(Obj?[] list)
  {
    list.each |v| { writeVal("item", v) }
  }

  private Void writeDict(Dict dict)
  {
    dict.each |v, n| { writeVal(n, v) }
  }

  private Void writeAttr(Str name, Str val)
  {
    out.writeChar(' ')
       .writeXml(name)
       .writeChar('=')
       .writeChar('\'')
       .writeXml(val, OutStream.xmlEscQuotes.or(OutStream.xmlEscNewlines))
       .writeChar('\'')
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private OutStream out

}