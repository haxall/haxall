//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 May 2021  Brian Frank  Creation
//

using concurrent
using web
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
  Ext? ext(Str name, Bool checked := true) { rt.exts.get(name, checked) }

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
    tags.addNotNull("projName", proj(false)?.name)
    tags["serverName"]       = Env.cur.host
    tags["serverBootTime"]   = DateTime.boot
    tags["serverTime"]       = DateTime.now
    tags["protocolVersions"] = ApiVersion.tokens
    tags["productName"]      = sys.info.productName
    tags["productUri"]       = sys.info.productUri
    tags["productVersion"]   = sys.info.productVersion
    tags["moduleName"]       = sys.typeof.pod.name
    tags["moduleVersion"]    = sys.typeof.pod.version.toStr
    tags["vendorName"]       = sys.info.vendorName
    tags["vendorUri"]        = sys.info.vendorUri
    tags["tz"]               = TimeZone.cur.name
    tags["whoami"]           = user.username
    tags["hostModel"]        = sys.info.hostModel
    tags.addNotNull("hostId", sys.info.hostId)
    return Etc.makeDict(tags)
  }

//////////////////////////////////////////////////////////////////////////
// Web
//////////////////////////////////////////////////////////////////////////

  ** Web request being serviced by this thread.  This is available to API
  ** functions which service the HTTP request themselves; see the `opWeb`
  ** marker.  Raise ContextUnavailableErr or return null based on checked
  ** flag if this thread is not servicing a web request.
  @NoDoc WebReq? webReq(Bool checked := true)
  {
    req := Actor.locals["web.req"] as WebReq
    if (req != null) return req
    if (checked) throw ContextUnavailableErr("No web request available")
    return null
  }

  ** Web response being serviced by this thread; see `webReq`.
  @NoDoc WebRes? webRes(Bool checked := true)
  {
    res := Actor.locals["web.res"] as WebRes
    if (res != null) return res
    if (checked) throw ContextUnavailableErr("No web response available")
    return null
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
  @NoDoc override final Dict? deref(Ref id)
  {
    derefRec(id) ?: derefNamespace(id)
  }

  ** Deref record from runtime database
  @NoDoc virtual Dict? derefRec(Ref id)
  {
    db.readById(id, false)
  }

  ** Deref spec or instance from runtime namespace
  @NoDoc virtual Dict? derefNamespace(Ref id)
  {
    if (!id.id.contains("::")) return null

    spec := ns.spec(id.id, false)
    if (spec != null) return spec

    instance := ns.instance(id.id, false)
    if (instance != null) return instance

    return null
  }

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
    return Etc.dictMerge(super.toDict, Etc.dictFromMap(tags))
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

  ** Return if context has access for the given write.  All writes
  ** require the admin permission.  Adds verify read access against
  ** the tags of the new record to prevent creating recs the user
  ** could not otherwise read.
  @NoDoc override Bool canWrite(FolioWrite w)
  {
    if (!user.isAdmin) return false
    if (w.oldRec == null) { Diff diff := w.diff; return canRead(diff.changes) }
    return true
  }

  ** Check security permissions to call given function
  @NoDoc override Void checkCall(Fn fn)
  {
    if (fn.isSu) checkSu(fn.name)
    else if (fn.isAdmin) checkAdmin(fn.name)
  }

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
  @NoDoc virtual FeedInit feedInit()
  {
    feedInitRef ?: throw Err("Feeds not supported")
  }

  ** Install feed initialization
  @NoDoc virtual FeedInit? feedInitRef

  ** In context a SkySpark feed
  @NoDoc virtual Bool feedIsEnabled() { false }

  ** Setup a feed (SkySpark only)
  @NoDoc virtual Void feedAdd(Feed feed, [Str:Obj?]? meta := null) {}

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

