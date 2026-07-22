//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2026  Brian Frank  Creation
//

using util
using xeto

**
** AFile models one Fantom source file containing @Gen types.
** All line numbers in the AST are zero based indices into lines.
**
internal class AFile
{
  new make(APod pod, File file, Str[] lines)
  {
    this.pod   = pod
    this.file  = file
    this.lines = lines
  }

  APod pod                 // parent pod
  const File file          // Fantom source file
  Str[] lines              // source lines, zero based
  AType[] types := [,]     // types tagged with @Gen
  AEdit[] edits := [,]     // GenEdits: line splices to apply

  ** Apply edits to the source lines to produce the generated lines
  Str[] genLines()
  {
    acc := lines.dup
    edits.sortr |a, b| { a.start <=> b.start }
    edits.each |e|
    {
      if (e.endEx > e.start) acc.removeRange(e.start..<e.endEx)
      acc.insertAll(e.start, e.lines)
    }
    return acc
  }

  Void dump(Console con := Console.cur)
  {
    con.group(file.osPath)
    types.each |t| { t.dump(con) }
    con.groupEnd
  }

  override Str toStr() { file.osPath }
}

