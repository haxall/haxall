//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2026  Brian Frank  Creation
//

**
** AEdit models one line splice in a source file: replace the zero
** based lines [start, endEx) with the new lines.  When start equals
** endEx the edit is an insert before start.
**
internal const class AEdit
{
  new make(Int start, Int endEx, Str[] lines)
  {
    this.start = start
    this.endEx = endEx
    this.lines = lines
  }

  const Int start        // first line to replace
  const Int endEx        // exclusive end line
  const Str[] lines      // new lines to splice in

  override Str toStr() { "[${start}..<${endEx}] ${lines.size} lines" }
}

