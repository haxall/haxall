//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Mar 2023  Brian Frank  Creation
//

using concurrent

**
** XetoContext is used to pass contextual state to XetoEnv operations.
**
@Js
mixin XetoContext : ActorContext
{
  ** Current context for actor thread
  ** NOTE: this will be replaced by just ActorContext.cur in 4.0
  @NoDoc static XetoContext? curXeto(Bool checked := true) { curx(checked) }

  ** Read a data record by id or return null
  @NoDoc abstract Dict? xetoReadById(Obj id)

  ** Read all the records that match given haytack filter
  @NoDoc abstract Obj? xetoReadAllEachWhile(Str filter, |Dict->Obj?| f)

  ** Return true if the given rec is nominally an instance of the given
  ** spec.  This is used by haystack Filters with a spec name.  The spec
  ** name may be qualified or unqualified.
  @NoDoc abstract Bool xetoIsSpec(Str spec, Dict rec)
}

**************************************************************************
** NilContext
**************************************************************************

@NoDoc @Js
const class NilXetoContext : XetoContext
{
  static const NilXetoContext val := make
  override Dict? xetoReadById(Obj id) { null }
  override Obj? xetoReadAllEachWhile(Str filter, |Dict->Obj?| f) { null }
  override Bool xetoIsSpec(Str spec, Dict rec) { false }
}

