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
using folio
using hx
using hxd
using hxFolio
using hxUser

internal class InitCli : HxCli
{
  override Str name() { "init" }

  override Str summary() { "Initialize a new daemon database" }

  @Opt { help = "Disables all prompts." }
  Bool headless := false

  @Opt { help = "HTTP port" }
  Int httpPort := 8080

  @Opt { help = "Disable HTTPS if configured" }
  Bool httpsDisable := false

  @Opt { help = "The su username. Required for headless mode." }
  Str? suUser

  @Opt { help = "The su user password. Used for headless, or one is auto-generated" }
  Str? suPass

  @Arg { help = "Runtime database directory" }
  File? dir

  override Int run()
  {
    init
    gatherInputs
    createDatabase

    printLine
    printLine("Success!")
    printLine

    if (showPassword)
    {
      printLine("--- Superuser account ---")
      printLine("Username: $suUser")
      printLine("Password: $suPass")
      printLine
    }

    return 0
  }

  private Void init()
  {
    // normalize runtime directory
    if (!dir.isDir) dir = dir.uri.plusSlash.toFile
    dir = dir.normalize

    // headless requires suUser
    if (headless && suUser == null) throw Err("suUser option is required for headless mode")

    // headless wihtout suPass generates one
    if (headless && suPass == null)
    {
      suPass = genPassword
      showPassword = true
    }

    printLine
    printLine("hx init [$dir.normalize.osPath]")
    printLine
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

  private Void createDatabase()
  {
    boot := HxdBoot()
    {
      it.dir = this.dir
      it.create = true
      it.log = Log.get("init")
    }

    rt := boot.init
    initHttpPort(rt)
    initSu(rt)
    rt.db.close
  }

  private Void initHttpPort(HxdRuntime rt)
  {
    rec := rt.db.read(Filter(Str<|ext=="http"|>))
    port := Number(httpPort)
    if (rec["httpPort"] != port)
    {
      rt.log.info("Update httpPort [$port]")
      rt.db.commit(Diff(rec, ["httpPort":port]))
    }
    if (httpsDisable && rec["httpsEnabled"] == true)
    {
      rt.log.info("Disable https")
      rt.db.commit(Diff(rec, ["httpsEnabled":Remove.val]))
    }
  }

  private Void initSu(HxdRuntime rt)
  {
    rec := rt.db.read(Filter("username==$suUser.toCode"), false)
    if (rec == null)
    {
      rt.log.info("Create su [$suUser.toCode]")
      HxUserUtil.addUser(rt.db, suUser, suPass, ["userRole":"su"])
    }
    else
    {
      rt.log.info("Update su $suUser.toCode")
      HxUserUtil.updatePassword(rt.db, rec, suPass)
    }
  }

  private static Str genPassword()
  {
    alphabet := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    mixed := alphabet.chars.shuffle
    buf := StrBuf()
    3.times |i|
    {
      5.times { buf.addChar(mixed[Int.random(0..<mixed.size)]) }
      if (i < 2) buf.addChar('-')
    }
    return buf.toStr
  }

  private Bool showPassword
}

