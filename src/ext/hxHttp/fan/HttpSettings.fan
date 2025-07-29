//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Dec 2015  Brian Frank  Creation
//   22 Sep 2021  Brian Frank  Port to Haxall
//

using xeto
using haystack
using hx

**
** Settings record
**
const class HttpSettings : Settings
{
  ** Constructor
  new make(Dict d, |This| f) : super(d) { f(this) }

  ** Public HTTP or HTTPS URI to use for URIs to this server.  This
  ** setting should be configured if running behind a proxy server
  ** where the local IP host or port isn't what is used for public
  ** access.  This URI must always address this machine and not
  ** another node in the cluster.
  @Setting
  const Uri? siteUri

  ** IP address to bind to locally for HTTP/HTTPS ports
  @Setting { restart=true }
  const Str? addr

  ** If false all traffic is handled in plaintext on 'httpPort'.  If set
  ** to true, then all traffic is forced to use HTTPS on 'httpsPort' and
  ** requests to 'httpPort' are redirected.
  @Setting { restart=true }
  const Bool httpsEnabled := false

  ** Port for HTTP traffic
  @Setting { restart=true }
  const Int httpPort := 8080

  ** Port for HTTPS; only applicable if 'httpsEnabled'
  @Setting { restart=true }
  const Int httpsPort := 443

  ** Max threads to allocate to service concurrent HTTP requests.
  @Setting { restart=true }
  const Int maxThreads := 500

  ** Disable showing exception stack trace for 500 internal server errors
  @Setting
  const Bool disableErrTrace := false
}

