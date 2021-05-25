//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 May 2021  Brian Frank  Creation
//

using concurrent
using haystack
using def
using axon
using folio

**
** Haxall execution and security context.
**
class HxContext : AxonContext, HaystackContext, FolioContext
{

//////////////////////////////////////////////////////////////////////////
// Current
//////////////////////////////////////////////////////////////////////////

  ** Current Haxall context for actor thread
  @NoDoc static HxContext? curHx(Bool checked := true)
  {
    cx := Actor.locals[Etc.cxActorLocalsKey]
    if (cx != null) return cx
    if (checked) throw Err("No HxContext available")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  @NoDoc new make(HxRuntime rt, HxUser user)
  {
    this.rtRef = rt
    this.userRef = user
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Runtime associated with this context
  virtual HxRuntime rt() { rtRef }
  private const HxRuntime rtRef

  ** Definition namespace associated for the runtime
  override Namespace ns() { rtRef.ns }

  ** Folio database for the runtime
  virtual Folio db() { rtRef.db }

  ** User account associated with this context
  virtual HxUser user() { userRef }
  private const HxUser userRef

//////////////////////////////////////////////////////////////////////////
// HaystackContext
//////////////////////////////////////////////////////////////////////////

  ** Dereference an id to an record dict or null if unresolved
  @NoDoc override Dict? deref(Ref id) { db.readById(id, false) }

  ** Return inference engine used for def aware filter queries
  @NoDoc override once FilterInference inference() { MFilterInference(ns) }

  ** Return contextual data as dict
  @NoDoc override Dict toDict()
  {
    tags := Str:Obj[:]
    tags["locale"] = Locale.cur.toStr
    tags["username"] = user.username
    if (timeout != null) tags["timeout"] = Number(timeout, Number.mins)
    return Etc.makeDict(tags)
  }

//////////////////////////////////////////////////////////////////////////
// FolioContext
//////////////////////////////////////////////////////////////////////////

  ** Return if context has read access to given record
  @NoDoc override Bool canRead(Dict rec) { true }

  ** Return if context has write (update/delete) access to given record
  @NoDoc override Bool canWrite(Dict rec) { user.isAdmin && canRead(rec) }

  ** Return an immutable thread safe object which will be passed thru
  ** the commit process and available via the FolioHooks callbacks.
  ** This is typically the User instance.  HxContext always returns user.
  @NoDoc override Obj? commitInfo() { user }

//////////////////////////////////////////////////////////////////////////
// AxonContext
//////////////////////////////////////////////////////////////////////////

  ** Find top-level function by qname or name
  @NoDoc override Fn? findTop(Str name, Bool checked := true)
  {
    def := ns.def("func:${name}", checked)
    if (def == null) return null
    throw Err("TODO: map func def to Fn expr")
  }

  ** Resolve dict by id - used by trap on Ref
  @NoDoc override Dict? trapRef(Ref id, Bool checked := true)
  {
    db.readById(id, checked)
  }

}