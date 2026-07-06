//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Dec 2015  Brian Frank  Creation
//   22 Sep 2021  Brian Frank  Port to Haxall
//

using concurrent
using inet
using web
using wisp
using haystack
using hx
using hxm

**
** HTTP service handling
**
const class HttpExt : ExtObj, IHttpExt
{
  WispService wisp() { wispRef.val ?: throw Err("Not ready") }
  private const AtomicRef wispRef := AtomicRef(null)

  ** Settings record
  override HttpSettings settings() { super.settings }

  ** Root WebMod instance
  override WebMod? root(Bool checked := true) { rootRef.val }

  ** Root WebMod instance to use when Wisp is launched
  const AtomicRef rootRef := AtomicRef(HttpRootMod(this))

  ** Public HTTP or HTTPS URI of this host.  This is always
  ** an absolute URI such `https://acme.com/`
  override Uri siteUri()
  {
    settings := this.settings
    if (settings.siteUri != null && !settings.siteUri.toStr.isEmpty)
      return settings.siteUri.plusSlash

    host := IpAddr.local.hostname
    if (settings.httpsEnabled)
      return `https://${host}:${settings.httpsPort}/`
    else
      return `http://${host}:${settings.httpPort}/`
  }

  ** Get the HTTP port or null if using HTTPS
  override Int? httpPort() { wisp.httpPort }

  ** Get the HTTPS port or null if using HTTP
  override Int? httpsPort() { wisp.httpsPort }

  ** Ready callback
  override Void onReady()
  {
    settings      := this.settings
    addr          := settings.addr?.trimToNull == null ? null : IpAddr(settings.addr)
    httpsEnabled  := settings.httpsEnabled
    socketConfig  := initSocketConfig

    if (httpsEnabled && socketConfig.keystore == null)
    {
      httpsEnabled = false
      log.err("Failed to obtain entry with alias 'https' from the keystore. Disabling HTTPS")
    }

    ephemeral := sys.config.has("ephemeralHttpPort")
    httpPort  := ephemeral ? -1 : settings.httpPort
    httpsPort := httpsEnabled ? settings.httpsPort : null

    wisp := WispService
    {
      it.httpPort     = httpPort
      it.httpsPort    = httpsPort
      it.addr         = addr
      it.maxThreads   = settings.maxThreads
      it.root         = this.root
      it.errMod       = it.errMod is WispDefaultErrMod ? HttpErrMod(this) : it.errMod
      it.socketConfig = socketConfig
    }
    wispRef.val = wisp
    wisp.start

    // don't return until wisp is listening
    wisp.waitUntilListening(30sec)
  }

  private SocketConfig initSocketConfig()
  {
    httpsKeyStore := sys.crypto.httpsKey(false)
    return SocketConfig.cur.copy { it.keystore = httpsKeyStore }
  }

  ** Unready callback
  override Void onUnready()
  {
    wisp.stop
  }

  ** Receive callback
  override Obj? onReceive(HxMsg msg)
  {
    if (msg.id == ExtMsgId.certModified.name) return onCertModified(msg.a)
    return super.onReceive(msg)
  }

  private Obj? onCertModified(Str alias)
  {
    if (alias != "https") return null
    log.info("HTTPS certificate rotated")
    wisp.socketConfig = initSocketConfig
    return "rotated"
  }

  ** Top-level hook to service all HTTP requests
  Void onService(WebReq req, WebRes res)
  {
    // try to dispatch the req based on the first level of the path
    routeName := req.modRel.path.first ?: ""
    if (routeExt(routeName, req, res)) return
    if (routeWellKnown(routeName, req, res)) return

    // if route name is empty then authenticate and perform index redirect
    if (routeName.isEmpty)
    {
      cx := sys.user.authenticate(req, res, sys)
      if (cx == null) return
      uri := indexRedirectUri(cx)
      return res.redirect(uri)
    }

    // 404 not found
    return res.sendErr(404)
  }

  ** Dispatch the given route to a webmod. Return true if handled.
  private Bool routeExt(Str routeName, WebReq req, WebRes res)
  {
    // lookup ext that handles this route
    mod := sys.exts.webRoutes.get(routeName)
    if (mod == null) return false

    // route it
    req.mod = mod
    req.modBase = req.modBase + `${routeName}/`
    mod.onService
    return true
  }

  ** Dispatch a well-known route. Return true if handled.
  **
  ** `/.well-known/{registeredName}[/path]`
  private Bool routeWellKnown(Str routeName, WebReq req, WebRes res)
  {
    if (routeName != ".well-known") return false

    // lookup .well-known handler for this route
    registeredName := req.modRel.path.getSafe(1) ?: ""
    mod := sys.exts.webRoutes.get("${routeName}/${registeredName}")
    if (mod == null) return false

    // route it
    req.mod = mod
    req.modBase = req.modBase + `${routeName}/`
    mod.onWellKnown
    return true
  }

  ** Where do we redirect for "/" such as "/ui/homeProj".
  virtual Uri indexRedirectUri(Context cx)
  {
    // if the userPasswordReset tag is set on the user, skip user specific
    // or OEM redirects and force use of the SkySpark UI (for password reset)
    user := cx.user
    if (user.meta.has("userPasswordReset")) return `/ui/`

    // handle defUri on the user account
    defUri := user.meta["defUri"] as Uri
    if (defUri != null) return defUri

    // use the extension web route with highest priority
    index := rt.exts.webIndex
    if (index.isUnsupported) return `/no-index`
    return index.indexRedirect(cx)
  }
}

