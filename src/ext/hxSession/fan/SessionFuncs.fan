//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Jun 2026  Matthew Giannini  Creation
//

using xeto
using haystack
using axon
using hx

@NoDoc @Gen
const class SessionFuncs
{
 private static SessionExt ext(Context cx := Context.cur) { cx.sys.ext("hx.session") }

  @NoDoc @Api @Axon { su = true }
  static Grid sessions() { ext.toGrid }

  // @NoDoc
  // static Str mfaStatus(ServerSession s)
  // {
  //   mfaStatus := "Unknown"
  //   if (s is WebServerSession)
  //   {
  //     sess := s as WebServerSession
  //     mfaStatus = sess.mfa.type.toStr.capitalize + "/" + sess.mfa.status.dis
  //   }
  //   else if (s is UiServerSession)
  //   {
  //     sess := s as UiServerSession
  //     mfaStatus = sess.parent.mfa.type.toStr.capitalize + "/" + sess.parent.mfa.status.dis
  //   }
  //   return mfaStatus
  // }

  @NoDoc @Api @Axon { su = true }
  static Grid sessionCountByUser()
  {
    gb := GridBuilder()
    gb.addCol("username").addCol("count")
    ext.sessionMap.userCountEach |u, c| { gb.addRow2(u, Number(c)) }
    return gb.toGrid
  }

  @NoDoc @Api @Axon { meta =
    Str<|disKey: "ui::logout"
         select
         su|> }
  static Obj? sessionLogout(Obj? sessionRefs)
  {
    ids := Etc.toIds(sessionRefs)
    ids.each |id|
    {
      session := ext.getById(id, false)
      if (session != null) ext.close(session)
    }
    return null
  }

  @NoDoc @Api @Axon { su = true }
  static Grid sessionDetails()
  {
    settings := ext.settings
    str := """webSessionTimeout: $settings.webSessionTimeout
              maxSessions:       $settings.maxSessions
              numSessions:       $ext.size
              """
    return Etc.makeMapGrid(["view":"text"], ["val":str])
  }
}
