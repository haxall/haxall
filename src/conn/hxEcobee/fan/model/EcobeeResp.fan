//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   02 Feb 2022  Matthew Giannini  Creation
//

**
** Synthetic type for Ecobee response object
**
const class EcobeeResp : EcobeeObj
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(|This| f)
  {
    f(this)
  }

  ** Page information
  const EcobeePage? page

  ** Response status
  const EcobeeStatus status

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  ** Are there more pages to fetch
  Bool morePages() { page?.morePages ?: false }
}
