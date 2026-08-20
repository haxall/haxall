//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Aug 2026  Brian Frank  Creation
//

using xeto
using haystack

**
** ApiUtil centralizes the special case checks for how an op function's
** spec drives HTTP dispatch.  Every rule the pipeline applies from func
** meta, params, or types is defined here so the contracts are co-located.
**
internal const class ApiUtil
{

//////////////////////////////////////////////////////////////////////////
// Func Spec Checks
//////////////////////////////////////////////////////////////////////////

  ** Op receives its request grid whole as its single parameter when the
  ** request arrives on a grid transport, rather than mapping the first
  ** row's cells to arguments by name
  static Bool isOpGrid(Spec func) { func.meta.has("opGrid") }

  ** Func reads the raw HTTP request itself and owns the method rules
  static Bool isOpWebReq(Spec func) { func.meta.has("opWebReq") }

  ** Func writes the raw HTTP response itself
  static Bool isOpWebRes(Spec func) { func.meta.has("opWebRes") }

  ** Op may be invoked with GET; otherwise POST is required
  static Bool allowGet(Spec func) { func.meta.has("noSideEffects") }

  ** Version 4 passed the request grid to any func invoked as an op no
  ** matter what it declared, so a func not marked '<op>' takes the grid
  ** whole for compatibility; a modeled op takes it whole only via opGrid
  static Bool takesReqGridV4(Spec func)
  {
    if (func.meta.missing("op")) return true
    return isOpGrid(func)
  }

  ** File typed param which receives the raw post body spooled to a temp
  ** file, or null when the op takes encoded args.  The file must be the
  ** op's only param since the body is consumed whole; a file param
  ** declared beside others is rejected when the args are mapped.
  static Spec? fileParam(Spec func)
  {
    func.func.isFileParam ? func.func.params.first : null
  }

//////////////////////////////////////////////////////////////////////////
// Request Checks
//////////////////////////////////////////////////////////////////////////

  ** Query params that control the request itself rather than supply an
  ** op argument.  The "xeto-" prefix mirrors the request header and is
  ** reserved: a xeto name cannot contain a dash, so a control param can
  ** never collide with an op parameter name.
  static Bool isControlParam(Str name) { name.startsWith("xeto-") }
}

