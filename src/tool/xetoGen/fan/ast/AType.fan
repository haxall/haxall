//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2026  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** AType models one Fantom type declaration tagged with the @Gen facet
**
internal class AType : ANode
{
  new make(AFile file, Str name, AFlags flags, AGen gen, Range? docLines, Range lines, Int bodyOpen, Range? items)
    : super(name, flags, gen, docLines, lines)
  {
    this.file     = file
    this.bodyOpen = bodyOpen
    this.items    = items
  }

  AFile file               // parent file
  const Int bodyOpen       // line of type's opening brace
  const Range? items       // enum item list lines or null
  ASlot[] slots := [,]     // @Gen tagged slot declarations
  Spec? spec               // FindTypes: resolved spec

  FileLoc loc() { FileLoc(file.file.osPath, lines.start+1) }

  Void dump(Console con := Console.cur)
  {
    s := StrBuf()
    s.add(name).add(": ").add(spec ?: "???")
    s.add(" [").add(lines.start+1).add("..").add(lines.end+1).add("]")
    if (!flags.toStr.isEmpty) s.add(" ").add(flags)
    s.add(" ").add(Etc.dictToStr(gen.meta))
    con.group(s.toStr)
    if (items != null) con.info("items [${items.start+1}..${items.end+1}]")
    slots.each |slot| { slot.dump(con) }
    con.groupEnd
  }
}

