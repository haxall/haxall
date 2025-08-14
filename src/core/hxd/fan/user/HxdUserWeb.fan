//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 May 2021  Brian Frank  Creation
//

using concurrent
using web
using haystack
using hx

**
** User library web servicing
**
const class HxdUserWeb : ExtWeb
{
  new make(HxdUserExt ext) : super(ext) { this.ext = ext }

  const override HxdUserExt ext

  override Void onService()
  {
    route := req.modRel.path.first
    switch (route)
    {
      case "login":       onLogin
      case "auth":        onAuth
      case "logout":      onLogout
      case "login.js":    onRes
      case "login.css":   onRes
      case "logo.svg":    onRes
      case "favicon.png": onRes
      default:            res.sendErr(404)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Login
//////////////////////////////////////////////////////////////////////////

  private Void onLogin()
  {
    // verify GET only
    if (req.method != "GET") { res.sendErr(501); return }

    // Login page constants
    // JavaScript: must escape using toCode
    // HTML: must escape using toXml or esc
    title          := "$<login.login>"
    userLabel      := "$<login.username>"
    passLabel      := "$<login.password>"
    loginLabel     := "$<login.login>"
    loggingInLabel := "$<login.loggingIn>"
    badCredsLabel  := "$<login.invalidUsernamePassword>"
    logoUri        := ext.sys.info.logoUri
    loginUri       := uri+`auth`
    redirectUri    := `/`

    res.headers["Content-Type"] = "text/html; charset=utf-8"
    out := res.out
    out.docType5.html.head.title.esc(title).titleEnd
       .includeCss(uri+`login.css`)
       .includeJs(uri+`login.js`)
    out.w("<meta name='viewport' content='user-scalable=no, width=device-width, initial-scale=1.0'/>").nl
    out.script.w(
        """hxLogin.passwordRequired = false;
           hxLogin.authUri = ${loginUri.encode.toStr.toCode};
           hxLogin.redirectUri = ${redirectUri.encode.toStr.toCode};
           hxLogin.localeLogin = ${loginLabel.toCode};
           hxLogin.localeLoggingIn = ${loggingInLabel.toCode};
           hxLogin.localeBadCreds = ${badCredsLabel.toCode};
           window.onload = function() { hxLogin.init(); }""").scriptEnd
    out.headEnd
      .body
      .form("id='loginForm' method='post' action='$loginUri.encode.toXml' autocomplete='off'")
        .p("class='logo'")
          .img(logoUri, "title='Haxall' alt='Haxall'")
        .pEnd
        .p("id='err'")
          .esc(badCredsLabel)
        .pEnd
        .p
          .label("for='username'").esc(userLabel).w(":").labelEnd
          .textField("id='username' name='username' autocomplete='off' placeholder='$userLabel.toXml'")
        .pEnd
        .p
          .label("for='password'").esc(passLabel).w(":").labelEnd
          .password("id='password' name='password' size='25' autocomplete='off' placeholder='$passLabel.toXml'")
        .pEnd
        .p
        .submit("id='loginButton' value='$loginLabel.toXml' onclick='return hxLogin.loginAuth();'")
        .pEnd
      .formEnd
      .bodyEnd
      .htmlEnd
  }

//////////////////////////////////////////////////////////////////////////
// Auth
//////////////////////////////////////////////////////////////////////////

  private Void onAuth()
  {
    HxdUserAuthServerContext(ext).onService(req, res)
  }

//////////////////////////////////////////////////////////////////////////
// Logout
//////////////////////////////////////////////////////////////////////////

  private Void onLogout()
  {
    session := ext.authenticate(req, res)
    if (session == null) return
    ext.sessions.close(session)
    res.redirect(ext.loginUri)
  }

//////////////////////////////////////////////////////////////////////////
// Resources
//////////////////////////////////////////////////////////////////////////

  private Void onRes()
  {
    file := typeof.pod.file(`/res/${req.modRel}`, false)
    if (file == null) return res.sendErr(404)
    FileWeblet(file).onService
  }

}

