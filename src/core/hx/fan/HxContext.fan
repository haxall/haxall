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
class HxContext : AxonContext, FolioContext
{

//////////////////////////////////////////////////////////////////////////
// Current
//////////////////////////////////////////////////////////////////////////

  ** Current Haxall context for actor thread
  @NoDoc static HxContext? curHx(Bool checked := true)
  {
    cx := ActorContext.curx(false)
    if (cx != null) return cx
    if (checked) throw ContextUnavailableErr("No HxContext available")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructor for project and user
  new make(Proj proj, User user)
  {
    this.projRef    = proj
    this.userRef    = user
    this.sessionRef = session
  }

  ** Constructor for session
  new makeSession(Proj proj, UserSession session)
  {
    this.projRef    = proj
    this.userRef    = session.user
    this.sessionRef = session
  }

** TODO
new makeTemp(Proj proj, User user, UserSession session)
{
  this.projRef    = proj
  this.userRef    = user
  this.sessionRef = session
}

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

virtual Proj rt() { proj }

  ** Project associated with this context
  virtual Proj proj() { projRef }
  private const Proj projRef

  ** Folio database for the project
  Folio db() { proj.db }

  ** Project namespace
  override Namespace ns() { proj.ns }

  ** Project legacy defs
  override DefNamespace defs() { proj.defs }

  ** User account associated with this context
  User user() { userRef }
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
    tags["locale"] = Locale.cur.toStr
    tags["username"] = user.username
    tags["userRef"] = user.id
    if (timeout != null) tags["timeout"] = Number(timeout, Number.mins)
    return Etc.dictMerge(super.toDict, tags)
  }

//////////////////////////////////////////////////////////////////////////
// Security
//////////////////////////////////////////////////////////////////////////

  ** If missing superuser permission, throw PermissionErr
  virtual Void checkSu(Str action)
  {
    if (!user.isSu)
      throw PermissionErr("Missing 'su' permission: $action")
  }

  ** If missing admin permission, throw PermissionErr
  virtual Void checkAdmin(Str action)
  {
    if (!user.isAdmin)
      throw PermissionErr("Missing 'admin' permission: $action")
  }

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
    // TODO
    return def.typeof.method("expr").callOn(def, null)
  }

 ** Evaluate an expression or if a filter then readAll convenience
  @NoDoc override Obj? evalOrReadAll(Str src)
  {
    expr := parse(src)
    filter := expr.evalToFilter(this, false)
    if (filter != null) return rt.db.readAll(filter)
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

