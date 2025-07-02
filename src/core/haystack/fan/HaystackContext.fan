//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Aug 2020  Brian Frank  Creation
//

using xeto

**
** HaystackContext defines an environment of defs and data
**
@Js
mixin HaystackContext : XetoContext
{
  ** Nil context has no data and no inference
  @NoDoc static HaystackContext nil() { nilRef }
  private static const NilContext nilRef := NilContext()

  ** Return true if the given rec is nominally an instance of the given
  ** spec.  This is used by haystack Filters with a spec name.  The spec
  ** name may be qualified or unqualified.
  @NoDoc override Bool xetoIsSpec(Str spec, Dict rec) { false }

  ** Read a data record by id or return null
  @NoDoc override Dict? xetoReadById(Obj id) { deref(id) }

  ** Read all the records that match given haystack filter
  @NoDoc override Obj? xetoReadAllEachWhile(Str filter, |Dict->Obj?| f) { null }

  ** Dereference an id to an record dict or null if unresolved
  @NoDoc abstract Dict? deref(Ref id)

  ** Return inference engine used for def aware filter queries
  @NoDoc abstract FilterInference inference()

  ** Return contextual data as dict - see context()
  @NoDoc abstract Dict toDict()
}

**************************************************************************
** NilContext
**************************************************************************

@Js
internal const class NilContext : HaystackContext
{
  override Dict? deref(Ref id) { null }
  override FilterInference inference() { FilterInference.nil }
  override Dict toDict() { Etc.emptyDict }
}

**************************************************************************
** PatherContext
**************************************************************************

** PatherContext provides legacy support for filter pathing
@NoDoc @Js
class PatherContext : HaystackContext
{
  new make(|Ref->Dict?| pather) { this.pather = pather }
  override Dict? deref(Ref id) { pather(id) }
  private |Ref->Dict?| pather
  override FilterInference inference() { FilterInference.nil }
  override Dict toDict() { Etc.emptyDict }
}

**************************************************************************
** HaystackFunc
**************************************************************************

** Mixin for Axon functions
@NoDoc @Js
mixin HaystackFunc
{
  ** Call the function
  abstract Obj? haystackCall(HaystackContext cx, Obj?[] args)
}

