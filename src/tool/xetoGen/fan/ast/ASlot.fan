//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2026  Brian Frank  Creation
//

using util

**
** ASlot models one @Gen tagged slot declaration in an AType body
**
internal class ASlot : ANode
{
  new make(Str name, AFlags flags, AGen gen, Range? docLines, Range lines, Bool hasBody)
    : super(name, flags, gen, docLines, lines)
  {
    this.hasBody = hasBody
  }

  const Bool hasBody       // does declaration include a body block
  AType? parent

  Void dump(Console con := Console.cur)
  {
    s := StrBuf()
    s.add(name).add(" [").add(lines.start+1).add("..").add(lines.end+1).add("]")
    if (!flags.toStr.isEmpty) s.add(" ").add(flags)
    con.info(s.toStr)
  }
}

