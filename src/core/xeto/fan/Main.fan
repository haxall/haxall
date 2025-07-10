//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Jun 2025  Brian Frank  Creation
//

using concurrent

**
** Stub to xetoEnv::Main
**
class Main
{
  static Int main(Str[] args)
  {
    // use doMain to avoid java transpile reflection issues
    Slot.findMethod("xetom::Main.doMain").callOn(null, [args])
  }
}

