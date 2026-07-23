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
  new make(AFile file, Str name, Spec spec, ATypeKind kind, AFlags flags, AGen gen, Range? docLines, Range lines, Int bodyOpen, Range? items)
    : super(name, flags, gen, docLines, lines)
  {
    this.file     = file
    this.spec     = spec
    this.kind     = kind
    this.bodyOpen = bodyOpen
    this.items    = items
  }

  AFile file               // parent file
  const Spec spec          // resolved spec
  const ATypeKind kind     // generation shape from spec
  const Int bodyOpen       // line of type's opening brace
  const Range? items       // enum item list lines or null
  ASlot[] slots := [,]     // @Gen tagged slot declarations
  Str[] handSlots := [,]   // untagged hand-written slot names in body

  FileLoc loc() { FileLoc(file.file.osPath, lines.start+1) }

  Void dump(Console con := Console.cur)
  {
    s := StrBuf()
    s.add(name).add(": ").add(spec)
    s.add(" (").add(kind).add(")")
    s.add(" [").add(lines.start+1).add("..").add(lines.end+1).add("]")
    if (!flags.toStr.isEmpty) s.add(" ").add(flags)
    if (!gen.meta.isEmpty) s.add(" ").add(Etc.dictToStr(gen.meta))
    con.group(s.toStr)
    if (items != null) con.info("items [${items.start+1}..${items.end+1}]")
    slots.each |slot| { slot.dump(con) }
    con.groupEnd
  }
}

**************************************************************************
** ATypeKind
**************************************************************************

**
** ATypeKind models the code generation shape for an AType
**
internal enum class ATypeKind
{
  comp,     // sys.comp::Comp subtype: get/set fields
  dict,     // Dict subtype: abstract getters
  enum,     // enum: item list
  funcs     // lib Funcs spec: align @Api static methods

  ** Map spec to its generation shape or null if unsupported.
  ** Comps must be checked before dicts since comps are dicts too.
  ** The funcs kind is assigned explicitly via the funcs meta tag.
  static ATypeKind? fromSpec(Namespace ns, Spec spec)
  {
    if (spec.isEnum) return ATypeKind.enum
    if (spec.isa(ns.spec("sys.comp::Comp"))) return comp
    if (spec.isa(ns.spec("sys::Dict"))) return dict
    return null
  }

  Bool isComp()  { this === comp }
  Bool isDict()  { this === dict }
  Bool isEnum()  { this === ATypeKind.enum }
  Bool isFuncs() { this === funcs }
}

