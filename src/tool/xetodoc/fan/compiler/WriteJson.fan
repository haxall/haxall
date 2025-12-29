//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using xetom

**
** Encode every top-level node to a JSON file
**
internal class WriteJson : Step
{
  override Void run()
  {
    if (compiler.outDir == null) return
    eachPage |entry|
    {
      writePage(entry)
    }
  }

  Void writePage(PageEntry entry)
  {
    obj := entry.page.encode
    json := JsonOutStream.prettyPrintToStr(obj)
    if (compiler.outDir == null)
      writeToMem(entry, json)
    else
      writeToFile(entry, json)
  }

  Void writeToMem(PageEntry entry, Str json)
  {
    file := Buf(json.size).print(json).toFile(entry.uriJson.name.toUri)
    compiler.files.add(file)
  }

  Void writeToFile(PageEntry entry, Str json)
  {
    file := compiler.outDir + entry.uriJson.relTo(`/`)
    file.out.print(json).close
    compiler.numFiles++
  }
}

