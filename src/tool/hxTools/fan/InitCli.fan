//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 May 2021  Brian Frank  Creation
//

using concurrent
using util
using haystack
using auth
using folio
using hx
using hxFolio

internal class InitCli : HxCli
{
  override Str name() { "init" }

  override Str summary() { "Initialize a new daemon database" }

  @Opt { help = "Disables all prompts." }
  Bool headless := false

  @Opt { help = "HTTP port" }
  Int httpPort := 8080

  @Opt { help = "The su username. Required for headless mode." }
  Str? suUser

  @Opt { help = "The su user password. Required for headless mode." }
  Str? suPass

  @Arg { help = "Runtime database directory" }
  File? dir

  override Int run()
  {
    init
    gatherInputs

    db := open
    initMeta(db)
    initLibs(db)
    initSu(db)
    close(db)

    printLine
    printLine("Success!")
    printLine

    return 0
  }

  private Void init()
  {
    // normalize runtime directory
    if (!dir.isDir) dir = dir.uri.plusSlash.toFile
    dir = dir.normalize

    // headless requires suPass
    if (headless && suUser == null) throw Err("suUser option is required for headless mode")
    if (headless && suPass == null) throw Err("suPass option is required for headless mode")
  }

  private Folio open()
  {
    dbDir := this.dir + `db/`

    if (dbDir.plus(`folio.index`).exists)
      printLine("Open database [$dbDir]")
    else
      printLine("Create database [$dbDir]")

    config := FolioConfig
    {
      it.name = "haxall"
      it.dir  = dbDir
      it.pool = ActorPool()
    }
    return HxFolio.open(config)
  }

  Void close(Folio db)
  {
    db.close
    printLine("Close database")
  }

  private Void gatherInputs()
  {
    if (headless) return

    printLine
    this.suUser = promptSu
    this.suPass = promptPassword
    this.httpPort = promptInt("http port", this.httpPort)
    printLine
  }

  private Bool promptConfirm(Str msg)
  {
    res := Env.cur.prompt("$msg (y/n)> ")
    if (res.lower == "y") return true
    return false
  }

  private Int promptInt(Str msg, Int def)
  {
    while (true)
    {
      res := Env.cur.prompt("$msg [$def]> ")
      if (res.isEmpty) return def
      int := Int.fromStr(res, 10, false)
      if (int != null) return int
    }
    throw Err()
  }

  private Str promptSu()
  {
    // prompt for name
    while (true)
    {
      username := Env.cur.prompt("su username> ")
      if (Ref.isId(username))
        return username
      else
        printLine("Not a valid username: '$username'")
    }
    throw Err()
  }

  private Str promptPassword()
  {
    while (true)
    {
      pass := Env.cur.promptPassword("su password> ")
      conf := Env.cur.promptPassword("su password (confirm)> ")
      if (pass != conf) { printLine("Not confirmed!"); continue }
      if (pass.isEmpty) { printLine("Password cannot be empty"); continue }
      return pass
    }
    throw Err()
  }

  private Void initMeta(Folio db)
  {
    rec := db.read("hxMeta", false)
    if (rec == null)
    {
      printLine("Create hxMeta")
      tags := ["hxMeta":Marker.val, "projMeta":Marker.val]
      db.commit(Diff.make(null, tags, Diff.add.or(Diff.bypassRestricted)))
    }
  }

  private Void initLibs(Folio db)
  {
    initLib(db, "ph")
    initLib(db, "phScience")
    initLib(db, "phIoT")
    initLib(db, "phIct")
    initLib(db, "hx")
    initLib(db, "hxdApi")
    initLib(db, "hxdHttp", ["httpPort":Number(httpPort)])
    initLib(db, "hxdUser")
  }

  private Void initLib(Folio db, Str name, Str:Obj changes := [:])
  {
    rec := db.read("hxLib==$name.toCode", false)
    if (rec == null)
    {
      printLine("Create lib [$name]")
      db.commit(Diff.makeAdd(["hxLib":name].addAll(changes)))
    }
    else
    {
      changes = changes.findAll |v, n| { rec[n] != v }
      if (changes.isEmpty) return
      printLine("Update lib [$name]")
      db.commit(Diff(rec, changes))
    }
  }

  private Void initSu(Folio db)
  {
    scram := ScramKey.gen
    userAuth := authMsgToDict(scram.toAuthMsg)
    secret := scram.toSecret(suPass)

    rec := db.read("username==$suUser.toCode", false)
    if (rec == null)
    {
      printLine("Create su [$suUser.toCode]")
      changes := [
        "username":suUser,
        "dis":suUser,
        "user":Marker.val,
        "userRole":"su",
        "userAuth": userAuth,
        "created": DateTime.now,
        "tz": TimeZone.cur.toStr,
        "disabled": Remove.val,
      ]
      db.commit(Diff.makeAdd(changes))
      db.passwords.set(suUser, secret)
    }
    else
    {
      printLine("Update su $suUser.toCode")
      changes := ["userAuth": userAuth]
      db.commit(Diff(rec, changes))
      db.passwords.set(suUser, secret)
    }
  }

  private Dict authMsgToDict(AuthMsg msg)
  {
     userAuth := Str:Obj["scheme": msg.scheme]
     msg.params.each |v, k|
     {
      if ("c" == k) userAuth[k] = Number(Int.fromStr(v, 10))
      else userAuth[k] = v
     }
     return Etc.makeDict(userAuth)
  }
}

