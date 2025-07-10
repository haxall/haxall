//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 May 2021  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using def
using axon
using folio
using hx

**
** Haxall daemon implementation of HxContextService
**
const class HxdContextService : HxContextService
{
  new make(HxdRuntime rt) { this.rt = rt }

  const HxdRuntime rt

  override HxContext create(HxUser user) { HxdContext(rt, user, null) }

  override HxContext createSession(HxSession session) { HxdContext(rt, session.user, session) }

  override Void xetoReload() { rt.nsBaseRecompile }

}

**************************************************************************
** HxdContext
**************************************************************************

**
** Haxall daemon implementation of HxContext
**
class HxdContext : HxContext
{

//////////////////////////////////////////////////////////////////////////
// Current
//////////////////////////////////////////////////////////////////////////

  ** Current Haxall context for actor thread
  @NoDoc static HxdContext? cur(Bool checked := true)
  {
    cx := Actor.locals[ActorContext.actorLocalsKey]
    if (cx != null) return cx
    if (checked) throw ContextUnavailableErr("No HxContext available")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  @NoDoc new make(HxdRuntime rt, HxUser user, HxSession? session)
  {
    this.rt = rt
    this.user = user
    this.sessionRef = session
  }

//////////////////////////////////////////////////////////////////////////
// HxContext
//////////////////////////////////////////////////////////////////////////

  override const HxdRuntime rt

  override Namespace ns() { rt.ns }

  override DefNamespace defs() { rt.defs }

  override Folio db() { rt.db }

  override const HxUser user

  override HxSession? session(Bool checked := true)
  {
    if (sessionRef != null) return sessionRef
    if (checked) throw SessionUnavailableErr("Context not associated with a session")
    return null
  }
  const HxSession? sessionRef

  override Dict about()
  {
    tags := Str:Obj?[:] { ordered = true }
    tags["haystackVersion"] = defs.lib("ph").version.toStr
    tags["serverName"]      = Env.cur.host
    tags["serverBootTime"]  = DateTime.boot
    tags["serverTime"]      = DateTime.now
    tags["productName"]     = rt.platform.productName
    tags["productUri"]      = rt.platform.productUri
    tags["productVersion"]  = rt.platform.productVersion
    tags["tz"]              = TimeZone.cur.name
    tags["vendorName"]      = rt.platform.vendorName
    tags["vendorUri"]       = rt.platform.vendorUri
    tags["whoami"]          = user.username
    return Etc.makeDict(tags)
  }

//////////////////////////////////////////////////////////////////////////
// XetoContext
//////////////////////////////////////////////////////////////////////////

  ** Read a data record by id
  @NoDoc override Dict? xetoReadById(Obj id)
  {
    db.readById(id, false)
  }

  ** Read all the records with a given tag name/value pair
  @NoDoc override Obj? xetoReadAllEachWhile(Str filter, |Dict->Obj?| f)
  {
    db.readAllEachWhile(Filter(filter), Etc.dict0, f)
  }

//////////////////////////////////////////////////////////////////////////
// HaystackContext
//////////////////////////////////////////////////////////////////////////

  ** Dereference an id to an record dict or null if unresolved
  @NoDoc override Dict? deref(Ref id) { db.readById(id, false) }

  ** Return inference engine used for def aware filter queries
  @NoDoc override once FilterInference inference() { MFilterInference(defs) }

  ** Return contextual data as dict
  @NoDoc override Dict toDict()
  {
    tags := Str:Obj[:]
    tags["locale"] = Locale.cur.toStr
    tags["username"] = user.username
    tags["userRef"] = user.id
    if (timeout != null) tags["timeout"] = Number(timeout, Number.mins)
    return Etc.dictMerge(super.toDict, tags)
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
    def := defs.def("func:${name}", false)
    if (def == null)
    {
      if (checked) throw UnknownFuncErr(name)
      return null
    }
    return ((FuncDef)def).expr
  }

  ** Resolve dict by id - used by trap on Ref
  @NoDoc override Dict? trapRef(Ref id, Bool checked := true)
  {
    db.readById(id, checked)
  }

  ** Evaluate an expression or if a filter then readAll convenience
  @NoDoc override Obj? evalOrReadAll(Str src)
  {
    expr := parse(src)
    filter := expr.evalToFilter(this, false)
    if (filter != null) return rt.db.readAll(filter)
    return expr.eval(this)
  }
}

