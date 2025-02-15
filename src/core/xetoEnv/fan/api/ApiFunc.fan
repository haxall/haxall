//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Feb 2025  Brian Frank  Creation
//

using xeto
using util

**
** ApiFunc implements one network API function endpoint
**
@Js
const mixin ApiFunc
{
  ** Invoke API request
  abstract Obj? call(ApiReq req)
}

**************************************************************************
** XetoApi Facet
**************************************************************************

** Facet applied to Fantom methods to bind them to a Xeto API spec
@Js facet class XetoApi {}

**************************************************************************
** ApiReq
**************************************************************************

** ApiFunc request payload
@Js
class ApiReq
{
}

**************************************************************************
** FantomApiFunc
**************************************************************************

** ApiFunc implementation bound to a Fantom method
@Js
internal const class FantomApiFunc : ApiFunc
{
  new make(Method method)
  {
    this.method = method
  }

  override Obj? call(ApiReq req)
  {
    method.call(req)
  }

  const Method method
}

