//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Apr 2021  Brian Frank  Creation
//

using util
using haystack
using def
using hx

internal class ConvertCli : HxCli
{
  override Str name() { "convert" }

  override Str summary() { "Convert between file formats" }

  @Opt { help = "Output directory" }
  File outDir := File(`./`)

  @Opt { help = "Comma separated output formats: zinc, json, trio, csv" }
  Str output := ""

  @Arg { help = "Input file(s) to convert" }
  File[] inputs := [,]

  override Int run()
  {
    formats := output.split(',')
    if (formats.isEmpty) return err("No output formats specified")

    if (inputs.isEmpty) return err("No input files specified")

    inputs.each |input|
    {
      formats.each |format| { convert(input, format) }
    }

    return 0
  }

  private Void convert(File inFile, Str format)
  {
    grid := read(inFile)
    outFile := outDir+ (inFile.basename + "." + format).toUri
    out := outFile.out
    printLine("$inFile.osPath  =>  $outFile.osPath")
    write(grid, format, out)
    out.close
    return 0
  }

  private Grid read(File file)
  {
    if (!file.exists) throw Err("Input file not found: $file")
    if (file.isDir) throw Err("Input file cannot be dir: $file")

    switch (file.ext)
    {
      case "zinc": return ZincReader(file.in).readGrid
      case "json": return JsonReader(file.in).readGrid
      case "trio": return TrioReader(file.in).readGrid
      case "csv":  return CsvReader(file.in).readGrid
      default:     throw Err("Unknown input file type: $file")
    }
  }

  private Void write(Grid grid, Str format, OutStream out)
  {
    switch (format)
    {
      case "zinc":   return ZincWriter(out).writeGrid(grid)
      case "json":   return JsonWriter(out).writeGrid(grid)
      case "trio":   return TrioWriter(out).writeGrid(grid)
      case "csv":    return CsvWriter(out).writeGrid(grid)
      case "jsonld": return JsonLdWriter(out, nsOpts).writeGrid(grid)
      case "turtle": return TurtleWriter(out, nsOpts).writeGrid(grid)
      default: throw Err("Unknown output format: $format")
    }
  }

  private Dict nsOpts() {  Etc.dict1("ns", ns) }

  // TODO
  private Namespace ns() { throw Err("Namespace formats not supported yet") }
}

