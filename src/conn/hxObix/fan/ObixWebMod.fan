//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Mar 2010  Brian Frank  Creation
//

using web
using obix
using xeto
using haystack
using hx

**
** ObixWebMod:
**   {base}                    // lobby
**   {base}/xsl                // style sheet
**   {base}/icon/{id}/{uri}    // icon tunnel
**
const class ObixWebMod : ObixMod
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(ObixExt ext) : super.make
    ([
      "serverName":     ext.proj.name,
      "vendorName":     ext.proj.platform.vendorName,
      "vendorUrl":      ext.proj.platform.vendorUri,
      "productName":    ext.proj.platform.productName,
      "productUrl":     ext.proj.platform.productUri,
      "productVersion": ext.typeof.pod.version.toStr,
    ])
  {
    this.proj = ext.proj
    this.ext = ext
  }

//////////////////////////////////////////////////////////////////////////
// Lib
//////////////////////////////////////////////////////////////////////////

  const Proj proj

  const ObixExt ext

//////////////////////////////////////////////////////////////////////////
// Service
//////////////////////////////////////////////////////////////////////////

  override Void onService()
  {
    cmd := req.modRel.path.getSafe(0)
    if (cmd == "icon")  { icon(req.stash["proj"]); return }
    super.onService
  }

  override ObixObj onRead(Uri uri) { resolve(uri).read }
  override ObixObj onWrite(Uri uri, ObixObj arg)  { resolve(uri).write(arg) }
  override ObixObj onInvoke(Uri uri, ObixObj arg) { resolve(uri).invoke(arg) }
  override ObixObj lobby() { ObixLobby(this).read }

  internal ObixObj defaultLobby() { super.lobby }

  private ObixProxy resolve(Uri uri)
  {
    ObixProxy? proxy := ObixLobby(this)
    uri.path.each |name, i|
    {
      proxy = proxy.get(name)
      if (proxy == null) throw UnresolvedErr(uri.toStr)
    }
    return proxy
  }

//////////////////////////////////////////////////////////////////////////
// Watches
//////////////////////////////////////////////////////////////////////////

  override ObixModWatch watchOpen()
  {
    w := proj.watch.open("Obix Server: $req.remoteAddr")
    return ObixWatch(this, w)
  }

  override ObixModWatch? watch(Str id)
  {
    w := proj.watch.get(id, false)
    if (w == null) return null
    return ObixWatch(this, w)
  }

//////////////////////////////////////////////////////////////////////////
// Icon Tunnel
//////////////////////////////////////////////////////////////////////////

  **
  ** Tunnel thru to get icon file:
  **   {base}/icon/{connId}/{uri}
  **
  private Void icon(Proj proj)
  {
    // only support GET
    if (req.method != "GET") { res.sendErr(501); return }

    // lookup record
    uri := req.modRel
    id := Ref.fromStr(uri.path.getSafe(1) ?: "", false)
    rec := proj.db.readById(id, false)
    if (rec == null) { blankIcon; return }

    // gather required obix fields
    // TODO: this doesn't use latest authentication strategy
    Uri obixLobby := rec->obixLobby
    Str username  := rec->username
    Str password  := proj.db.passwords.get(rec.id.toStr) ?: ""

    // make GET request to obix service
    iconUri := obixLobby + uri.getRangeToPathAbs(2..-1)
    c := WebClient(iconUri)
    c.reqMethod = "GET"
    c.reqHeaders["Authorization"] = "Basic " + "$username:$password".toBuf.toBase64
    c.writeReq.readRes

    // map tunneled headers to my response
    status := c.resCode
    ct := c.resHeaders["Content-Type"] ?: "error"
    cl := c.resHeaders["Content-Length"]

    // for security, we only allow tunneling of image content
    if (status != 200 || !ct.startsWith("image")) {
    blankIcon; return }

    // pipe result back
    res.statusCode = status
    res.headers["Content-Type"] = ct
    if (cl != null) res.headers["Content-Length"] = cl
    c.resIn.pipe(res.out)
  }

  private Void blankIcon()
  {
    f := Pod.find("fresco").file(`fan://frescoRes/img/blank-x16.png`)
    FileWeblet(f).onGet
  }

}

