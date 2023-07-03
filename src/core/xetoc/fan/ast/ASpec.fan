//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Mar 2023  Brian Frank  Creation
//   3 Jul 2023  Brian Frank  Redesign the AST
//

using util
using xeto

**
** AST spec
**
@Js
internal class ASpec : ANode
{
   ** Constructor
  new make(FileLoc loc, ALib lib, ASpec? parent, Str name) : super(loc)
  {
    this.lib    = lib
    this.parent = parent
    this.qname  = parent == null ? "${lib.name}::$name" : "${parent.qname}.$name"
    this.name   = name
    this.asm    = XetoSpec()
  }

  ** Parent library
  ALib lib { private set }

  ** Parent spec or null if this is top-level spec
  ASpec? parent { private set }

  ** Name within lib or parent
  const Str name

  ** Qualified name
  const Str qname

  ** XetoSpec for this spec - we backpatch the "m" field in Assemble step
  const XetoSpec asm

  ** Type signature
  ATypeRef? typeRef

  ** Meta dict if <>
  ADict? meta { private set }

  ** Initialize meta data dict
  ADict initMeta(ADict? meta := null)
  {
    if (this.meta == null)
    {
      if (meta == null) meta = ADict(this.loc, null)
      meta.isMeta = true
      this.meta = meta
    }
    return this.meta
  }

  ** Slots if {}
  [Str:ASpec]? slots

  ** Default value
  AScalar? val

  ** Debug dump
  override Void dump(OutStream out := Env.cur.out, Str indent := "")
  {
    indentMore := indent + "  "
    out.print(indent).print(name).print(": ")
    if (typeRef != null) out.print(typeRef).print(" ")
    if (meta != null) meta.dump(out, indentMore)
    if (slots != null)
    {
      out.printLine("{")
      slots.each |s|
      {
        s.dump(out, indentMore)
        out.printLine
      }
      out.print(indent).print("}")
    }
    if (val != null) out.print(" = ").print(val)
  }
}


