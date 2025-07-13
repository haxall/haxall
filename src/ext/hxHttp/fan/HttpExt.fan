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
const class HttpExt : ExtObj, HxHttpService
{
  WispService wisp() { wispRef.val }
  private const AtomicRef wispRef := AtomicRef(null)

  ** Publish the HxHttpService
  override HxService[] services() { [this] }

  ** Settings record
  override HttpSettings rec() { super.rec }

  ** Root WebMod instance
  override WebMod? root(Bool checked := true) { rootRef.val }

  ** Root WebMod instance to use when Wisp is launched
  const AtomicRef rootRef := AtomicRef(HttpRootMod(this))

  ** Public HTTP or HTTPS URI of this host.  This is always
  ** an absolute URI such 'https://acme.com/'
  override Uri siteUri()
  {
    settings := this.rec
    if (settings.siteUri != null && !settings.siteUri.toStr.isEmpty)
      return settings.siteUri.plusSlash

    host := IpAddr.local.hostname
    if (settings.httpsEnabled)
      return `https://${host}:${settings.httpsPort}/`
    else
      return `http://${host}:${settings.httpPort}/`
  }

  ** URI on this host to the Haystack HTTP API.  This is always
  ** a host relative URI which end withs a slash such '/api/'.
  override Uri apiUri() { `/api/` }

  ** Ready callback
  override Void onReady()
  {
    settings      := this.rec
    addr          := settings.addr?.trimToNull == null ? null : IpAddr(settings.addr)
    httpsEnabled  := settings.httpsEnabled
    httpsKeyStore := proj.crypto.httpsKey(false)
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
}

