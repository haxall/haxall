//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Feb 2022  Matthew Giannini  Creation
//

**
** Function object
**
const class EcobeeFunction : EcobeeObj
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(|This| f) { f(this) }

  new makeFields(Str type, Map params)
  {
    this.type   = type
    this.params = params
  }

  ** The function type name
  const Str? type

  ** The function parameters
  const Map? params
}