//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Nov 2010  Brian Frank  Creation
//

using hx

**
** I/O functions
**
const class IOExt : ExtObj, IIOExt
{

  override Obj? read(Obj? handle, |InStream->Obj?| f)
  {
    IOHandle.fromObj(proj, handle).withIn(f)
  }

  override Obj? write(Obj? handle, |OutStream| f)
  {
    IOHandle.fromObj(proj, handle).withOut(f)
  }

}

