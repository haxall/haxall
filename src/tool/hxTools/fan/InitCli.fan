//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 May 2021  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack
using folio
using hx
using hxd
using hxm
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

  @Opt { help = "The su username for headless, defaults to su" }
  Str? suUser

  @Opt { help = "The su user password for headless, defaults to auto-generated" }
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
    if (headless && suUser == null)
    {
      suUser = "su"
    }

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
    boot := HxdBoot("sys", this.dir)
    {
      it.log = Log.get("init")
    }

    if (!boot.dir.plus(`db/folio.index`).exists)
    {
      log.info("Creating new database [$boot.dir]")
      boot.create
    }

    // now load it
    proj := HxdSys(boot).init(boot)
    initHttpPort(proj)
    initSu(proj)
    proj.db.close
  }

  private Void initHttpPort(Proj proj)
  {
    ext := proj.ext("hx.http")
    settings := ext.settings
    port := Number(httpPort)
    if (settings["httpPort"] != port)
    {
      log.info("Update httpPort [$port]")
      ext.settingsUpdate(["httpPort":port])
    }
    if (httpsDisable && settings["httpsEnabled"] == true)
    {
      log.info("Disable https")
      ext.settingsUpdate(["httpsEnabled":Remove.val])
    }
  }

  private Void initSu(Proj proj)
  {
    rec := proj.read("username==$suUser.toCode", false)
    if (rec == null)
    {
      log.info("Create su [$suUser.toCode]")
      HxUserUtil.addUser(proj.db, suUser, suPass, ["userRole":"su"])
    }
    else
    {
      log.info("Update su $suUser.toCode")
      HxUserUtil.updatePassword(proj.db, rec, suPass)
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

