//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Mar 2023  Brian Frank  Creation
//

using util
using data

**
** AST value type compiles into:
**  - scalar: via AObj.val
**  - typeRef: via AObj.type (if type+meta, then should be nested ASpec)
**  - list: via asmListOf and AObj.slots
**  - dict: via AObj.slots
**
@Js
internal class AVal: AObj
{
   ** Constructor
  new make(FileLoc loc, AObj? parent, Str name) : super(loc, parent, name) {}

  ** Return true
  override Bool isVal() { true }

  ** Determine how to assemble this value
  AValType valType()
  {
    if (val != null) return AValType.scalar
    if (val == null && slots == null) return AValType.typeRef
    if (asmToListOf != null) return AValType.list
    return AValType.dict
  }

  ** Assembled value - raise exception if not assembled yet
  override Obj asm() { asmRef ?: throw NotAssembledErr() }

  ** Construct nested value
  override AObj makeChild(FileLoc loc, Str name) { AVal(loc, this, name) }

  ** Assembled value set in Reify
  Obj? asmRef

  ** Flag to indicate this value should be assembled to a
  ** list and what the List.of type should be
  Type? asmToListOf

}

**************************************************************************
** AValType
**************************************************************************

@Js
internal enum class AValType { scalar, typeRef, list, dict }