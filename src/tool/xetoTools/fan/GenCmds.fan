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
  Void write(Uri file, |OutStream| cb)
  {
    info("write [$file]")
    f := outDir + file
    out := f.out
    try
    {
      out.printLine("//")
      out.printLine("// Copyright (c) 2011-2023, Project-Haystack")
      out.printLine("// Licensed under the Academic Free License version 3.0")
      out.printLine("// Auto-generated $ts")
      out.printLine("//")
      out.printLine
      cb(out)
    }
    finally out.close
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
    name = name.replace("-", " ")
    name = name.replace("/", " ")
    return Etc.toTagName(name)
  }
  private const Str ts := DateTime.now.toLocale("DD-MMM-YYYY")

}

**************************************************************************
** GenTz
**************************************************************************

internal class GenTz: AbstractGenCmd
{
  override Str name() { "gen-tz" }

  override Str summary() { "Compile timezone db into sys::TimeZone" }

  @Opt { help = "Directory to output" }
  override File outDir := (Env.cur.workDir + `../xeto/src/xeto/sys/`).normalize

  override Int run()
  {
    if (!outDir.plus(`types.xeto`).exists) throw Err("Invalid outDir: $outDir")

    write(`timezones.xeto`) |out|
    {
      out.printLine("// TimeZone names for standardized database")
      out.printLine("TimeZone: Enum {")
      TimeZone.listNames.each |name|
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

  override Str summary() { "Compile unit db into sys::Unit" }

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