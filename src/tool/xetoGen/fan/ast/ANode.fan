//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2026  Brian Frank  Creation
//

**
** ANode is the base class for AType and ASlot declarations.
** Line numbers are zero based; lines spans the full declaration
** including doc comment, facets, signature, and body.
**
abstract internal class ANode
{
  new make(Str name, AFlags flags, AGen gen, Range? docLines, Range lines)
  {
    this.name     = name
    this.flags    = flags
    this.gen      = gen
    this.docLines = docLines
    this.lines    = lines
  }

  const Str name           // Fantom type/slot name
  const AFlags flags       // declaration modifiers
  const AGen gen           // @Gen facet
  const Range? docLines    // doc comment lines or null
  const Range lines        // full declaration line range

  override Str toStr() { name }
}

