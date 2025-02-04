//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Dec 2023  Brian Frank  Creation
//

using util
using haystack

**
** AbstractGenCmd
**
internal abstract class AbstractGenCmd : XetoCmd
{

  ** Output directory
  abstract File outDir()

  ** Write given file under phDir
  Void write(Uri uri, |OutStream| cb)
  {
    buf := StrBuf()
    out := buf.out
    out.printLine("//")
    out.printLine("// Copyright (c) 2011-2025, Project-Haystack")
    out.printLine("// Licensed under the Academic Free License version 3.0")
    out.printLine("// Auto-generated $ts")
    out.printLine("//")
    out.printLine
    cb(out)
    contents := buf.toStr

    // check if file has changed
    file := outDir + uri
    if (isFileChanged(file, contents))
    {
      info("write [$file.osPath]")
      file.out.print(contents).close
    }
    else
    {
      info(" skip [$file.osPath]")
    }
  }

  static Bool isFileChanged(File file, Str newContents)
  {
    if (!file.exists) return true
    oldContents := file.readAllStr
    tsLine := 3
    newLines := newContents.trim.splitLines
    oldLines := oldContents.trim.splitLines
    if (!newLines[tsLine].contains("Auto-generated")) throw Err()
    newLines.removeRange(0..tsLine)
    oldLines.removeRange(0..tsLine)
    return newLines != oldLines
  }

  ** Write doc comment
  Void writeDoc(OutStream out, Def def)
  {
    doc := def["doc"] as Str ?: def.name
    doc.splitLines.each |line|
    {
      out.printLine("// $line".trimEnd)
    }
  }

  ** Log message to stdout
  Void info(Str msg)
  {
    echo(msg)
  }

  ** Map enum name with special cares to programmatic name
  Str normEnumName(Str name)
  {
    // map L1-L2 to pL1L2"
    if (name.startsWith("L") && name[1].isDigit)
      name = "p" + name

    name = name.replace("-", " ")
    name = name.replace("/", " ")
    return Etc.toTagName(name)
  }

  const Str ts := DateTime.now.toLocale("DD-MMM-YYYY")

}

**************************************************************************
** GenTz
**************************************************************************

internal class GenTz: AbstractGenCmd
{
  override Str name() { "gen-tz" }

  override Str summary() { "Generate Xeto sys 'tz.xeto' source code" }

  @Opt { help = "Directory to output" }
  override File outDir := (Env.cur.workDir + `../xeto/src/xeto/sys/`).normalize

  override Int run()
  {
    if (!outDir.plus(`types.xeto`).exists) throw Err("Invalid outDir: $outDir")

    write(`timezones.xeto`) |out|
    {
      out.printLine("// TimeZone names for standardized database")
      out.printLine("TimeZone: Enum {")
      names := TimeZone.listNames.dup
      names.moveTo("UTC", 0)
      names.each |name|
      {
        key := name
        if (key.startsWith("GMT-"))
          name = "gmtMinus" + key[4..-1]
        else if (key.startsWith("GMT+"))
          name = "gmtPlus" + key[4..-1]
        else
          name = normEnumName(name)
        out.printLine("  $name <key:$key.toCode>")
      }
      out.printLine("}")
    }

    return 0
  }
}

**************************************************************************
** GenUnits
**************************************************************************

internal class GenUnits : AbstractGenCmd
{
  override Str name() { "gen-units" }

  override Str summary() { "Generate Xeto sys 'unit.xeto' source code" }

  @Opt { help = "Directory to output" }
  override File outDir := (Env.cur.workDir + `../xeto/src/xeto/sys/`).normalize

  override Int run()
  {
    if (!outDir.plus(`types.xeto`).exists) throw Err("Invalid outDir: $outDir")

    quantities := Str[,]
    write(`units.xeto`) |out|
    {
      out.printLine("// Unit symbols for standardized database")
      out.printLine("Unit: Enum {")
      Unit.quantities.each |q|
      {
        quantityMeta := null
        if (q != "dimensionless")
        {
          quantityName := normEnumName(q)
          quantities.add(quantityName)
          quantityMeta = ", quantity:${quantityName.toCode}"
        }

        Unit.quantity(q).each |u|
        {
          out.print("  $u.name <key:$u.symbol.toCode")
          if (quantityMeta != null) out.print(quantityMeta)
          out.printLine(">")
        }
        out.printLine
      }
      out.printLine("}")
      out.printLine

      out.printLine("// Unit quantity types for standardized database")
      out.printLine("UnitQuantity: Enum {")
      quantities.each |q|
      {
        out.printLine("  $q")
      }
      out.printLine("}")
    }

    return 0
  }
}

**************************************************************************
** GenWriter
**************************************************************************

class GenWriter
{
  new make(File file) { this.file = file }

  const File file

  This w(Obj x) { buf.add(x); return this }

  This str(Obj? x) { if (x == null) x = ""; return w(x.toStr.toCode); }

  This nl() { w("\n") }

  Void close()
  {
    //echo("\n### $file.osPath ###\n$buf\n")
    echo("Output [$file.osPath]")
    file.out.print(buf.toStr).close
  }

  StrBuf buf := StrBuf()
}

