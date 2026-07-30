//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jul 2026  Brian Frank  Creation
//

using xeto
using haystack
using axon
using hx
using web

**
** ApiDispatchV5 for version 5 xeto protocol
**
class ApiDispatchV5 : ApiDispatch
{
  new make(ApiPipeline p) : super(p) {}

  override Obj?[] readReqGet() { throw Err("TODO") }

  override Obj?[] readReqPost() { throw Err("TODO") }

  override Void writeRes(Obj? result) { throw Err("TODO") }
}

