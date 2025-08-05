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
using axon
using folio

**
** Haxall execution and security context.
**
class Context : AxonContext, FolioContext
{

//////////////////////////////////////////////////////////////////////////
// Current
//////////////////////////////////////////////////////////////////////////

  ** Current context for actor thread
  static Context? cur(Bool checked := true)
  {
    cx := ActorContext.curx(false)
    if (cx != null) return cx
    if (checked) throw ContextUnavailableErr("No Context available")
    return null
  }

  ** Run function using this Context as the current one.
  ** This method automatically saves/restore the existing context.
  @NoDoc Obj? asCur(|Context->Obj?| f)
  {
    old := Actor.locals[actorLocalsKey]
    Actor.locals[actorLocalsKey] = this
    try
      return f(this)
    finally
      Actor.locals[actorLocalsKey] = old
  }

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Runtime.newContext constructor for sys, project, and user.
  protected new make(Sys sys, Proj? proj, User user)
  {
    this.rtRef    = proj ?: sys
    this.sysRef   = sys
    this.projRef  = proj
    this.userRef  = user
  }

  ** Constructor for session
  @NoDoc new makeSession(Sys sys, Proj? proj, UserSession session)
  {
    this.rtRef      = proj ?: sys
    this.sysRef     = sys
    this.projRef    = proj
    this.userRef    = session.user
    this.sessionRef = session
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Runtime is the project if available, or sys as fallback
  virtual Runtime rt() { rtRef }
  private const Runtime rtRef

  ** System
  virtual Sys sys() { sysRef.sys }
  private const Sys sysRef

  ** Project associated with this context
  virtual Proj? proj(Bool checked := true)
  {
    if (projRef != null) return projRef
    if (checked) throw ProjUnavailableErr("No project associated with context")
    return null
  }
  private const Proj? projRef

  ** Folio database for the runtime
  Folio db() { rt.db }

  ** Runtime namespace
  override Namespace ns() { rt.ns }

  ** Runtime legacy defs (deprecated)
  @NoDoc override DefNamespace defs() { rt.defs }

  ** Convenience to lookup ext in runtime
  Ext ext(Str name, Bool checked := true) { rt.exts.get(name, checked) }

  ** User account associated with this context
  virtual User user() { userRef }
  private const User userRef

  ** Authentication session associated with this context if applicable
  UserSession? session(Bool checked := true)
  {
    if (sessionRef != null) return sessionRef
    if (checked) throw SessionUnavailableErr("Context not associated with a session")
    return null
  }
  private const UserSession? sessionRef

  ** About data to use for HTTP API
  @NoDoc virtual Dict about()
  {
    tags := Str:Obj?[:] { ordered = true }
    tags["haystackVersion"] = defs.lib("ph").version.toStr
    tags["serverName"]      = Env.cur.host
    tags["serverBootTime"]  = DateTime.boot
    tags["serverTime"]      = DateTime.now
    tags["productName"]     = sys.info.productName
    tags["productUri"]      = sys.info.productUri
    tags["productVersion"]  = sys.info.productVersion
    tags["tz"]              = TimeZone.cur.name
    tags["vendorName"]      = sys.info.vendorName
    tags["vendorUri"]       = sys.info.vendorUri
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
  @NoDoc override once FilterInference inference() { throw UnsupportedErr() }

  ** Return contextual data as dict
  @NoDoc override Dict toDict()
  {
    tags := Str:Obj[:]
    tags.ordered = true
    tags["projName"] = rt.name
    tags["projDis"]  = rt.dis
    tags["username"] = user.username
    tags["userRef"]  = user.id
    tags["locale"]   = Locale.cur.toStr
    tags.addNotNull("nodeId", sys.cluster(false)?.nodeId)
    tags.addNotNull("timeout", timeout == null ? null : Number(timeout, Number.mins))
    return Etc.dictFromMap(tags)
  }

//////////////////////////////////////////////////////////////////////////
// Security
//////////////////////////////////////////////////////////////////////////

  ** If missing superuser permission, throw PermissionErr
  Void checkSu(Str action)
  {
    if (!user.isSu && !user.access.allow(action))
      throw PermissionErr("Missing 'su' permission: $action")
  }

  ** If missing admin permission, throw PermissionErr
  Void checkAdmin(Str action)
  {
    if (!user.isAdmin && !user.access.allow(action))
      throw PermissionErr("Missing 'admin' permission: $action")
  }

  ** Return if context has read access to given record
  @NoDoc override Bool canRead(Dict rec) { true }

  ** Return if context has write (update/delete) access to given record
  @NoDoc override Bool canWrite(Dict rec) { user.isAdmin && canRead(rec) }

  ** Return an immutable thread safe object which will be passed thru
  ** the commit process and available via the FolioHooks callbacks.
  ** This is typically the User instance.  Context always returns user.
  @NoDoc override Obj? commitInfo() { user }

//////////////////////////////////////////////////////////////////////////
// AxonContext
//////////////////////////////////////////////////////////////////////////

  ** Evaluate an expression or if a filter then readAll convenience
  @NoDoc override Obj? evalOrReadAll(Str src)
  {
    expr := parse(src)
    filter := expr.evalToFilter(this, false)
    if (filter != null) return db.readAll(filter)
    return expr.eval(this)
  }

//////////////////////////////////////////////////////////////////////////
// Feeds
//////////////////////////////////////////////////////////////////////////

  ** Feed initialization
  @NoDoc virtual HxFeedInit feedInit()
  {
    feedInitRef ?: throw Err("Feeds not supported")
  }

  ** Install feed initialization
  @NoDoc virtual HxFeedInit? feedInitRef

  ** In context a SkySpark feed
  @NoDoc virtual Bool feedIsEnabled() { false }

  ** Setup a feed (SkySpark only)
  @NoDoc virtual Void feedAdd(HxFeed feed, [Str:Obj?]? meta := null) {}

//////////////////////////////////////////////////////////////////////////
// SkySpark Context virtuals
//////////////////////////////////////////////////////////////////////////

  ** Clear read cache for subclasses
  @NoDoc virtual Void readCacheClear() {}

  ** Export to outpout stream - SkySpark only
  @NoDoc virtual Obj export(Dict req, OutStream out)
  {
    throw UnsupportedErr("Export not supported")
  }
}

