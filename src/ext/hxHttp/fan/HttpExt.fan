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

**
** HTTP service handling
**
const class HttpExt : ExtObj, IHttpExt
{
  WispService wisp() { wispRef.val }
  private const AtomicRef wispRef := AtomicRef(null)

  ** Settings record
  override HttpSettings settings() { super.settings }

  ** Root WebMod instance
  override WebMod? root(Bool checked := true) { rootRef.val }

  ** Root WebMod instance to use when Wisp is launched
  const AtomicRef rootRef := AtomicRef(HttpRootMod(this))

  ** Public HTTP or HTTPS URI of this host.  This is always
  ** an absolute URI such 'https://acme.com/'
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

  ** Ready callback
  override Void onReady()
  {
    settings      := this.settings
    addr          := settings.addr?.trimToNull == null ? null : IpAddr(settings.addr)
    httpsEnabled  := settings.httpsEnabled
    httpsKeyStore := sys.crypto.httpsKey(false)
    socketConfig  := SocketConfig.cur.copy { it.keystore = httpsKeyStore }

    if (httpsEnabled && httpsKeyStore == null)
    {
      httpsEnabled = false
      log.err("Failed to obtain entry with alias 'https' from the keystore. Disabling HTTPS")
    }

    wisp := WispService
    {
      it.httpPort     = settings.httpPort
      it.httpsPort    = httpsEnabled ? settings.httpsPort : null
      it.addr         = addr
      it.maxThreads   = settings.maxThreads
      it.root         = this.root
      it.errMod       = it.errMod is WispDefaultErrMod ? HttpErrMod(this) : it.errMod
      it.socketConfig = socketConfig
    }
    wispRef.val = wisp
    wisp.start
  }

  ** Unready callback
  override Void onUnready()
  {
    wisp.stop
  }

  ** Top-level hook to service all HTTP requests
  Void onService(WebReq req, WebRes res)
  {
    // use first level of my path to lookup route
    routeName := req.modRel.path.first ?: ""

    // get the webmod for given route
    mod := sys.exts.webRoutes.get(routeName)
    if (mod != null)
    {
      // dispatch to web mod
      req.mod = mod
      req.modBase = req.modBase + `$routeName/`
      mod.onService
      return
    }

    // if route name is empty then authenticate and perform index redirect
    if (routeName.isEmpty)
    {
      session := sys.user.authenticate(req, res)
      if (session == null) return
      cx := sys.newContextSession(session)
      uri := indexRedirectUri(cx)
      return res.redirect(uri)
    }

    // 404 not found
    return res.sendErr(404)
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

