//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2026  Matthew Giannini  Creation
//

using concurrent
using xeto
using haystack
using hx

**
** Manages file access checks for the file ext
**
const class FileAccess
{
  new make(Mount mount)
  {
    this.mount = mount
  }

  const Mount mount
  Context cx() { mount.cx }
  User user() { cx.user }

  ** Return true if the file extension of the uri is in the whitelist
  virtual Bool whitelisted(Uri uri) { true }

  virtual Bool allowed(Uri uri, Str mode)
  {
    // check if context has an override for checking access
    res := checkOverride(uri, mode)
    if (res != null) return res

    // do custom mount accessibility checks before standard file access filters
    if (!mount.precheckAllowed(uri, mode)) return false

    // superuser has access to every file
    if (user.isSu) return true

    // check admin access
    if (checkAdmin) return true

    // last we check file grants
    return checkGrants(uri, mode)
  }

  ** If there is an access override in the context return its result. Otherwise
  ** return null to keep going with normal file access checks.
  protected virtual Bool? checkOverride(Uri uri, Str mode)
  {
    func := cx.stash["hxFile.allowed"] as Func
    // TODO: this check should be deprecated and removed; this is the old name
    if (func == null) func = cx.stash["fileMod.isFileAccessible"] as Func
    if (func != null) return func.call(cx, uri, mode)
    return null
  }

  ** Admins have access to every file unless one of the the file
  ** access tags is configured
  protected virtual Bool checkAdmin()
  {
    meta := user.meta
    return user.isAdmin &&
           meta.missing("fileAccess") &&
           meta.missing("fileAccessReadOnly")
  }

  protected virtual Bool checkGrants(Uri uri, Str mode)
  {
    // build access grants
    absUri := mount.mountAbs(uri)
    meta   := user.meta
    grants := AccessGrant[,]
    (meta["fileAccess"] as Uri[] ?: Uri[,]).each |grant|
    {
      grants.addNotNull(toGrant(grant, "rw"))
    }
    (meta["fileAccessReadOnly"] as Uri[] ?: Uri[,]).each |grant|
    {
      grants.addNotNull(toGrant(grant, "r"))
    }

    allowAccess := false
    AccessGrant? best := null
    grants.each |g|
    {
      // grant uri must be a directory
      if (!g.uri.isDir) return

      // is the uri a child of this grant directory
      isUnder := g.uri.path.size < absUri.path.size && absUri.pathStr.startsWith(g.uri.pathStr)
      if (isUnder)
      {
        // is this the longest/most-specific grant found so far? if so,
        // determine access based on this grant
        if (best == null || g.uri.path.size > best.uri.path.size)
        {
          best = g
          allowAccess = g.accept(mode)
        }
      }
      else if (mode == "r")
      {
        // user only has read access to a parent directory of a granted
        // directory. this is necessary for file listing/traversal
        if (!absUri.isDir) return
        Uri? cur := absUri
        while (true)
        {
          if (cur == `/` || cur == null) break
          if (g.uri.pathStr.startsWith(absUri.pathStr))
          {
            allowAccess = true
            break
          }
          cur = cur.parent
        }
      }
    }
    return allowAccess
  }

  protected virtual AccessGrant? toGrant(Uri grant, Str mode) { AccessGrant(grant, mode) }
}

**************************************************************************
** AccessGrant
**************************************************************************

@NoDoc const class AccessGrant
{
  new make(Uri uri, Str mode)
  {
    if (!uri.isPathAbs) throw IOErr("Not absolute: $uri")
    this.uri = uri
    this.readable = mode.contains("r")
    if (mode.contains("w"))
    {
      this.readable = true
      this.writable = true
    }
  }

  const Uri uri
  const Bool writable := false
  const Bool readable := false

  Bool accept(Str mode)
  {
    if (mode.contains("w")) return writable
    if (mode.contains("r")) return readable
    return false
  }

  override Str toStr()
  {
    s := StrBuf().add("$uri")
    if (writable) s.add(" [rw]")
    else if (readable) s.add(" [r]")
    return s.toStr
  }
}