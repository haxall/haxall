//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Jul 2026  Brian Frank  Creation
//

using concurrent
using inet
using web
using xeto
using haystack
using hx

**
** HttpTest tests hxHttp web routing
**
class HttpTest : HxTest
{
  Uri? siteUri

//////////////////////////////////////////////////////////////////////////
// Virtual Hosts
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testVirtualHost()
  {
    addHttpExt
    this.siteUri = sys.http.siteUri

    // no IWwwExt installed -> virtual host falls through to 404
    verifyGet("test.acme.com", `/about`, 404, null)

    // hx.test provides IWwwExt and claims hostname via settings
    proj.libs.add("hx.test")
    ext := proj.ext("hx.test")
    ext.settingsUpdate(Etc.dict1("vhost", "test.acme.com"))
    syncVhosts(ext)

    // virtual host services the host's path space minus system routes
    verifyGet("test.acme.com", `/`,         200, "vhost test.acme.com /")
    verifyGet("test.acme.com", `/about`,    200, "vhost test.acme.com /about")
    verifyGet("test.acme.com", `/doc/xeto`, 200, "vhost test.acme.com /doc/xeto")

    // hostname normalized lowercase with port stripped
    verifyGet("Test.ACME.com:8080", `/about`, 200, "vhost test.acme.com /about")

    // system routes still win over the virtual host claim
    verifyGet("test.acme.com", `/test/foo`, 200, "route test /test/foo")

    // unclaimed hostname does not dispatch to virtual host
    verifyGet("other.acme.com", `/about`, 404, null)

    // settings change rebinds the vhost table: new domain claims,
    // old domain released
    ext.settingsUpdate(Etc.dict1("vhost", "other.acme.com"))
    syncVhosts(ext)
    verifyGet("other.acme.com", `/about`, 200, "vhost other.acme.com /about")
    verifyGet("test.acme.com", `/about`, 404, null)

    // removing the ext drops its claim
    proj.libs.remove("hx.test")
    syncVhosts(ext)
    verifyGet("other.acme.com", `/about`, 404, null)
  }

  ** Drain the claiming ext's actor (sends vhostsModified) then the
  ** http ext's actor (processes the table rebuild)
  private Void syncVhosts(Ext ext)
  {
    ext.spi.sync
    sys.http.spi.sync
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Raw socket request so we control the Host header
  private Void verifyGet(Str host, Uri path, Int code, Str? body)
  {
    socket := TcpSocket().connect(IpAddr(siteUri.host), siteUri.port)
    try
    {
      socket.out.print("GET $path HTTP/1.1\r\nHost: $host\r\nConnection: close\r\n\r\n").flush
      verifyEq(socket.in.readLine.split[1].toInt, code)
      headers := WebUtil.parseHeaders(socket.in)
      if (body != null) verifyEq(WebUtil.makeContentInStream(headers, socket.in).readAllStr, body)
    }
    finally socket.close
  }
}
