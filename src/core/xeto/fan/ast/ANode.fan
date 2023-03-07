//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Mar 2023  Brian Frank  Creation
//

using util

**
** Base class for AST nodes
**
@Js
internal abstract class ANode
{
  ** Node type
  abstract ANodeType nodeType()

  ** Source code location
  abstract FileLoc loc()

  ** Assembled value - raise NotAssembledErr if not assembled
  abstract Obj asm()

  ** Walk AST tree
  abstract Void walk(|ANode| f)

}

**************************************************************************
** ANodeType
**************************************************************************

@Js
internal enum class ANodeType { ref, val, spec, type, lib }

**************************************************************************
** NotAsmErr
**************************************************************************

@Js
internal const class NotAssembledErr : Err { new make() : super("") {} }

