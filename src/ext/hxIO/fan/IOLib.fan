//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Nov 2010  Brian Frank  Creation
//

using hx

**
** I/O function library
**
const class IOLib : HxLib, HxIOService
{
  override HxService[] services() { [this] }

  override Obj? read(Obj? handle, |InStream->Obj?| f)
  {
    IOHandle.fromObj(rt, handle).withIn(f)
  }

  override Obj? write(Obj? handle, |OutStream| f)
  {
    IOHandle.fromObj(rt, handle).withOut(f)
  }

}


