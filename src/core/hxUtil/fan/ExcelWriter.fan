//
// Copyright (c) 2011, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Jul 2011  Andy Frank  Creation
//

using haystack

@Js
@NoDoc
class ExcelWriter : GridWriter
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Wrap output stream
  new make(OutStream out) { this.out = ExcelOutStream(out) }

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  ** Flush the underlying output stream and return this
  This flush() { out.flush; return this }

  ** Close the underlying output stream
  Bool close() {  out.close }

  ** Write grid and return this
  override This writeGrid(Grid grid) { writeWorkbook([grid]) }

  ** Write a workbook file, each grid is one worksheet
  This writeWorkbook(Grid[] grids)
  {
    // compute styling for all grid values
    grids.each |grid| { computeStyling(grid) }

    // open workbook
    out.workbook

    // add styles for every tz
    out.styles
    styleToTz.keys.sort.each |style|
    {
      tz := styleToTz[style]
      out.styleNumberFormat(style, "yyyy-mm-dd hh:mm:ss \"$tz\"")
    }

    // add styles for every unit
    styleToUnit.keys.sort.each |style|
    {
      unit := styleToUnit[style]
      if (unit === Number.dollar)
        out.styleNumberFormat(style, "\"\$\"0.00")
      else
        out.styleNumberFormat(style, "0.0\"$unit\"")
    }
    out.stylesEnd

    // worksheets for each grid
    grids.each |grid| { writeWorksheet(grid) }

    out.workbookEnd
    return this
  }

  private Void computeStyling(Grid grid)
  {
    grid.each |row|
    {
      row.each |v| { checkStyle(v) }
    }
  }

  private Void checkStyle(Obj? val)
  {
    if (val is Number) return checkStyleNumber(val)
    if (val is DateTime) return checkStyleDateTime(val)
  }

  private Void checkStyleNumber(Number num)
  {
    u := num.unit
    if (u != null && unitToStyle[u] == null)
    {
      style := "U" + unitToStyle.size
      unitToStyle[u] = style
      styleToUnit[style] = u
    }
  }

  private Void checkStyleDateTime(DateTime ts)
  {
    tz := ts.tzAbbr
    if (tzToStyle[tz] == null)
    {
      style := "DT" + tzToStyle.size
      tzToStyle[tz] = style
      styleToTz[style] = tz
    }
  }

  private Void writeWorksheet(Grid grid)
  {
    title := grid.meta["title"] as Str
    out.worksheet(title).table

    // column widths
    cols := grid.cols
    cols.each |col| { out.col(colWidth(grid, col)) }

    // header row with column names
    out.row(true)
    cols.each |col| { out.cell(col.dis) }
    out.rowEnd

    // rows
    grid.each |row|
    {
      out.row
      cols.each |col|
      {
        val := row.val(col)
        if (val is Number)
        {
          num  := (Number)val
          style := num.unit != null ? unitToStyle[num.unit] : null
          out.cellNumber(num.toFloat, style)
        }
        else if (val is DateTime)
        {
          ts := (DateTime)val
          style := tzToStyle[ts.tzAbbr]
          out.cellDateTime(val, style)
        }
        else
        {
          out.cell(dis(row, col))
        }
      }
      out.rowEnd
    }

    out.tableEnd
    out.worksheetEnd
  }

  private Int colWidth(Grid grid, Col col)
  {
    chars := col.dis.size
    grid.each |row| { chars = chars.max(dis(row, col).size) }
    return 40.max(chars * 6).min(140)
  }

  private Str dis(Row row, Col col)
  {
    val := row.val(col)
    if (val == null) return ""
    if (val is Ref) return ((Ref)val).dis
    if (val === Marker.val) return "\u2713"
    return val.toStr
  }

  private ExcelOutStream out
  private Unit:Str unitToStyle := [:]
  private Str:Unit styleToUnit := [:]
  private Str:Str tzToStyle := [:]
  private Str:Str styleToTz := [:]

}

**************************************************************************
** ExcelOutStream
**************************************************************************

**
** ExcelOutStream produces Excel 2003 XML spreadsheet documents.
**
@Js
@NoDoc
internal class ExcelOutStream : OutStream
{
  new make(OutStream out) : super(out) {}

//////////////////////////////////////////////////////////////////////////
// Workbook
//////////////////////////////////////////////////////////////////////////

  ** Start a new <Workbook> tag.
  This workbook()
  {
    printLine(
      """<?xml version="1.0" encoding="UTF-8"?>
         <Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
          xmlns:o="urn:schemas-microsoft-com:office:office"
          xmlns:x="urn:schemas-microsoft-com:office:excel"
          xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"
          xmlns:html="http://www.w3.org/TR/REC-html40">""")
  }

  ** End a <Workbook> tag.
  This workbookEnd()
  {
    printLine("</Workbook>")
  }

//////////////////////////////////////////////////////////////////////////
// Styling
//////////////////////////////////////////////////////////////////////////

  ** Start a new <Styles> tag.
  This styles()
  {
    printLine(
      """<Styles>
           <Style ss:ID="HeaderRow">
             <Font ss:Bold="1" />
           </Style>
           <Style ss:ID="DT">
              <NumberFormat ss:Format="yyyy-mm-dd hh:mm:ss"/>
           </Style>""")
  }

  ** Add complete <Style> tag for number formating.
  This styleNumberFormat(Str key, Str format)
  {
    printLine(
      """  <Style ss:ID="$key">
              <NumberFormat ss:Format="$format.toXml"/>
           </Style>""")
  }

  ** End the <Styles> tag.
  This stylesEnd()
  {
    printLine("</Styles>")
  }

//////////////////////////////////////////////////////////////////////////
// Worksheet
//////////////////////////////////////////////////////////////////////////

  ** Start a new <Worksheet> tag.
  This worksheet(Str? name := null)
  {
    if (name == null) name = "Sheet${sheet}"
    printLine("""$in1<Worksheet ss:Name="$name.toXml">""")
    sheet++
    return this
  }

  ** End a <Worksheet> tag.
  This worksheetEnd()
  {
    printLine("$in1</Worksheet>")
  }

//////////////////////////////////////////////////////////////////////////
// Table
//////////////////////////////////////////////////////////////////////////

  ** Start a new <Table> tag.
  This table()
  {
    // <Table ss:ExpandedColumnCount="3" ss:ExpandedRowCount="2"
    //  x:FullColumns="1" x:FullRows="1">
    printLine("""$in2<Table>""")
  }

  ** End a <Table> tag.
  This tableEnd()
  {
    printLine("$in2</Table>")
  }

//////////////////////////////////////////////////////////////////////////
// Col
//////////////////////////////////////////////////////////////////////////

  ** Write <Column> tag with given width.
  This col(Int width)
  {
    printLine("""$in2<Column ss:Width="$width"/>""")
  }

//////////////////////////////////////////////////////////////////////////
// Row
//////////////////////////////////////////////////////////////////////////

  ** Start a new <Row> tag.
  This row(Bool header := false)
  {
    if (header)
      printLine("$in3<Row ss:StyleID=\"HeaderRow\">")
    else
      printLine("$in3<Row>")
    return this
  }

  ** End a <Row> tag.
  This rowEnd()
  {
    printLine("$in3</Row>")
  }

//////////////////////////////////////////////////////////////////////////
// Cell
//////////////////////////////////////////////////////////////////////////

  ** Write a complete <Cell> tag for Number
  This cellNumber(Float val, Str? style := null)
  {
    if (val.isNaN || val == Float.posInf || val == Float.negInf)
      return cell(val.toStr, "String", style)
    else
      return cell(val.toStr, "Number", style)
  }

  ** Write a complete <Cell> tag for DateTime
  This cellDateTime(DateTime val, Str? style := null)
  {
    cell(val.toLocale("YYYY-MM-DD'T'hh:mm:ss.FFF"), "DateTime", style)
  }

  ** Write a complete <Cell> tag for given value.
  This cell(Str val, Str type := "String", Str? style := null)
  {
    attr := style != null ? " ss:StyleID=\"$style\"" : ""
    printLine("""$in4<Cell$attr><Data ss:Type="$type">$val.toXml</Data></Cell>""")
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Test
//////////////////////////////////////////////////////////////////////////

  /*
  static Void main()
  {
    f := `test.xls`.toFile
    out := ExcelOutStream(f.out)
    out.workbook.worksheet.table

    out.col(20).col(20)

    out.row.cell("r1").cell("100", "Number").rowEnd
    out.row.cell("r2").cell("2.3", "Number").rowEnd
    out.row.cell("r3").cell("4.5", "Number").rowEnd

    out.tableEnd.worksheetEnd.workbookEnd
    out.close
  }
  */

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const Str in1 := " "
  private const Str in2 := "  "
  private const Str in3 := "   "
  private const Str in4 := "    "

  private Int sheet := 1
}