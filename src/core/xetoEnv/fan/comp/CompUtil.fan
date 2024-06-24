//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Nov 2023  Brian Frank  Creation
//   21 May 2024  Brian Frank  Port into xetoEnv
//

using xeto

**
** CompUtil
**
@Js
class CompUtil
{

  ** Return if name is a slot that cannot be directly changed in an Comp
  static Bool isReservedSlot(Str name)
  {
    name == "id" || name == "spec"
  }

  ** Convert slot to fantom handler method or null
  static Method? toHandlerMethod(Comp c, Spec slot)
  {
    c.typeof.method(toHandlerMethodName(slot.name), false)
  }

  ** Convert component slot "name" to Fantom method implementation "onName"
  static Str toHandlerMethodName(Str name)
  {
    StrBuf(name.size + 1)
      .add("on")
      .addChar(name[0].upper)
      .addRange(name, 1..-1)
      .toStr
  }

}

