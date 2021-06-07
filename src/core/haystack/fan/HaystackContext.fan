//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Aug 2020  Brian Frank  Creation
//

**
** HaystackContext defines an environment of defs and data
**
@Js
mixin HaystackContext
{
  ** Nil context has no data and no inference
  @NoDoc static HaystackContext nil() { nilRef }
  private static const NilContext nilRef := NilContext()

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

