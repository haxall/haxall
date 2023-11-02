//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Feb 2022  Matthew Giannini  Creation
//

using concurrent
using crypto
using util
using haystack
using hx

internal class CryptoCli : HxCli
{

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private File dir := Env.cur.workDir + `var/`

  private const Str[] args := Env.cur.args
  private [Str:Str]? argsMap
  private Str? action

//////////////////////////////////////////////////////////////////////////
// HxCli
//////////////////////////////////////////////////////////////////////////

  override Str name() { "crypto" }

  override Str summary() { "Manage crypto keys and certificates" }

  override Int run()
  {
    switch (action)
    {
      case "add":    doAddKey
      case "trust":  doTrust
      case "export": doExport
      case "list":   doList
      case "remove": doRemove
      case "rename": doRename
      default:
        err("Unsupported action: $action.toCode")
        return usage
    }
    return 0
  }

  private once KeyStore keystore()
  {
    cryptoDir := dir.plus(`crypto/`).normalize
    if (!cryptoDir.exists) { exitErr("crypto directory does not exist: $cryptoDir") }

    keystoreFile := cryptoDir.plus(`keystore.p12`)
    if (!keystoreFile.exists) { exitErr("keystore not found: $keystoreFile") }

    pool := ActorPool { it.name = "CryptoCli" }
    keystore := Type.find("hxCrypto::CryptoKeyStore").make([pool, keystoreFile, log])

    return keystore
  }

//////////////////////////////////////////////////////////////////////////
// Add Key
//////////////////////////////////////////////////////////////////////////

  private Void doAddKey()
  {
    if (helpRequested) return usageAdd

    alias := argsMap["alias"]
    ks    := keystore
    x := hasArg("import")
      ? import(alias, keystore)
      : readPEMs(alias, keystore)
    info("SUCCESS! Key added with alias '${alias}'")
  }

  private Obj? import(Str alias, KeyStore keystore)
  {
    if (!hasArg("import")) usageAdd("-import required")

    file := parseArgToFile(argsMap["import"])
    pass := argsMap["pass"]
    if (!file.exists) exitErr("Import file does not exist: $file")

    ks := Crypto.cur.loadKeyStore(file, ["password": pass])
    entry := ks.aliases.eachWhile |Str name->PrivKeyEntry?| {
      e := ks.get(name)
      if (e isnot PrivKeyEntry) return null
      return e
    }
    if (entry == null) exitErr("Key store does not contain entry with private key and certifcate chain")
    return keystore.set(alias, entry)
  }

  private Obj? readPEMs(Str alias, KeyStore keystore)
  {
    if (!hasArg("priv")) usageAdd("-priv required")
    if (!hasArg("certs")) usageAdd("-certs required")

    // read private key
    in := parseArgToFile(argsMap["priv"]).in
    privKey := Crypto.cur.loadPem(in) as PrivKey
    in.close

    // read cert chain
    certs := Crypto.cur.loadX509(parseArgToFile(argsMap["certs"]).in)

    return keystore.setPrivKey(alias, privKey, certs)
  }

//////////////////////////////////////////////////////////////////////////
// Trust
//////////////////////////////////////////////////////////////////////////

  private Void doTrust()
  {
    if (helpRequested) usageTrust

    certs := Cert[,]
    if (hasArg("uri"))
      certs = Crypto.cur.loadCertsForUri(argsMap["uri"].toUri)
    else if (hasArg("cert"))
      certs = Crypto.cur.loadX509(parseArgToFile(argsMap["cert"]).in)
    else usageTrust("-cert or -uri required")

    force := hasArg("force") || hasArg("f")
    alias := argsMap["alias"]
    if (alias == null)
    {
      // =<alias>, ....
      cert  := certs.first
      equal := cert.subject.index("=")
      comma := cert.subject.index(",")
      if (equal == null || comma == null || comma < equal)
        exitErr("Cannot auto-generate alias for ${cert.subject}. Use -alias option")
      alias = cert.subject[3..<comma].replace(" ","").lower
    }

    ks := keystore
    certs.each |cert, i|
    {
      entryAlias := i == 0 ? alias : "${alias}.$i"
      if (ks.containsAlias(entryAlias))
      {
        if (!force)
        {
          info("Entry with alias '${entryAlias}' already exists. Use -f to overwrite")
          return
        }
      }
      info("Trusting ${cert.subject} as ${entryAlias}\n")
      ks.setTrust(entryAlias, cert)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Export
//////////////////////////////////////////////////////////////////////////

  private Void doExport()
  {
    if (helpRequested) return usageExport
    if (!hasArg("alias")) usageExport("-alias option is required")

    alias := argsMap["alias"]
    entry := keystore.get(alias)

    if (entry is TrustEntry)
    {
      trust := (TrustEntry)entry
      f := File(`${alias}-trusted.cert`)
      f.out.writeChars(trust.cert.toStr).close
      printLine("Exported ${alias} to: ${f.normalize.osPath}")
    }
    else
    {
      key := (PrivKeyEntry)entry

      // @NoDoc support to also export the private key
      if (hasArg("priv"))
      {
        f := File(`${alias}-priv.key`)
        f.out.writeChars(key.priv.toStr).close
        printLine("Exported ${alias} private key to: ${f.normalize.osPath}")
      }

      f   := File(`${alias}-cert.crt`)
      out := f.out
      key.certChain.each |cert| { out.writeChars(cert.toStr) }
      out.close
      printLine("Exported ${alias} certificate chain to: ${f.normalize.osPath}")
    }
  }

//////////////////////////////////////////////////////////////////////////
// List Action
//////////////////////////////////////////////////////////////////////////

  private Void doList()
  {
    if (helpRequested) return usageList

    ks := this.keystore
    aliases := hasArg("alias") ? [argsMap["alias"]] : ks.aliases
    aliases.each |alias|
    {
      entry := ks.get(alias, false)
      buf := StrBuf()
      if (entry is PrivKeyEntry)
      {
        pk := entry as PrivKeyEntry
        buf.add("[private key] ${pk.cert.subject}")
      }
      else if (entry is TrustEntry)
      {
        cert := (entry as TrustEntry).cert
        buf.add("[trusted certificate]\n")
        buf.add("  Subject: ${cert.subject}")
        if (cert.subject != cert.issuer) buf.add("\n   Issuer: ${cert.issuer}")
      }
      else if (entry == null)
      {
        buf.add("NOT FOUND")
      }
      info("${alias}: ${buf}")
    }
  }

//////////////////////////////////////////////////////////////////////////
// Remove
//////////////////////////////////////////////////////////////////////////

  private Void doRemove()
  {
    if (helpRequested) usageRemove
    if (!hasArg("alias")) usageRemove("-alias required")

    alias := argsMap["alias"]
    ks    := keystore
    if (!ks.containsAlias(alias)) exitErr("No entry with alias '$alias'")
    ks.remove(alias)
    info("Removed $alias")
  }

//////////////////////////////////////////////////////////////////////////
// Rename
//////////////////////////////////////////////////////////////////////////

  private Void doRename()
  {
    if (helpRequested) usageRename
    if (!hasArg("alias")) usageRename("-alias required")
    if (!hasArg("to")) usageRename("-to required")

    ks    := keystore
    alias := argsMap["alias"]
    to    := argsMap["to"]
    force := hasArg("force") || hasArg("f")
    keep  := hasArg("keep")

    if (!ks.containsAlias(alias)) return info("No entry with alias '$alias'")
    if (ks.containsAlias(to) && !force) return info("Entry with alias '$to' already exists. Use -force option to rename")

    entry := ks.get(alias)
    ks.set(to, entry)
    if (!keep) ks.remove(alias)

    info("renamed $alias to $to")
  }

//////////////////////////////////////////////////////////////////////////
// Action Args
//////////////////////////////////////////////////////////////////////////

  override Bool parseArgs(Str[] args)
  {
    if (args.isEmpty) { err("No action specified"); return false }

    this.argsMap = Str:Str[:]
    this.action = args.first

    // parse command lines arg "-key [val]"
    envArgs := this.args[1..-1]
    envArgs.each |s, i|
    {
      if (!s.startsWith("-") || s.size < 2) return
      name := s[1..-1]
      val  := "true"
      if (i+1 < envArgs.size && !envArgs[i+1].startsWith("-"))
        val = envArgs[i+1]
      this.argsMap[name] = val
    }

    if (hasArg("d")) this.dir = parseArgToDir(argsMap["d"])
    else if (hasArg("var")) this.dir = parseArgToDir(argsMap["var"])

    return true
  }

  ** Was the given action argument specified?
  private Bool hasArg(Str arg) { argsMap.containsKey(arg) }

  ** Was one of the help options specified?
  private Bool helpRequested() { hasArg("help") || hasArg("?") }

  private static File parseArgToFile(Str val)
  {
    if (val.contains("\\"))
      return File.os(val).normalize
    else
      return File.make(val.toUri, false)
  }

  private static File parseArgToDir(Str val)
  {
    f := parseArgToFile(val)
    if (f.isDir) return f
    return f.uri.plusSlash.toFile
  }

//////////////////////////////////////////////////////////////////////////
// Usage
//////////////////////////////////////////////////////////////////////////

  private Void info(Str msg) { printLine(msg) }

  private Void exitErr(Str msg)
  {
    err(msg)
    Env.cur.exit(2)
  }

  override Int usage(OutStream out := Env.cur.out)
  {
    out.printLine(
      "Usage:
         hx crypto <action> <action options>* <options>*

       Actions:
         add     Adds a private key + certificate chain entry to the keystore
         trust   Adds a trusted certificate to the keystore
         export  Export an entry from the keystore
         remove  Removes an entry from the keystore
         list    List summary information about entries in the keystore
         rename  Rename an entry's alias in the keystore

       Options:
         -d <dir>    Path to directory containing crypto/ (default = $dir)
         -var <dir>  Alias for -d <dir>
         -help, -?   Print usage help.

       Use 'hx crypto <action> -help' to get action-specific help")
    return 1
  }

  private Void usageAdd(Str? err := null, OutStream out := Env.cur.out)
  {
    if (err != null) this.err(err)
    out.printLine(
      "Add:
         hx crypto add -alias <alias> -priv <file> -certs <file>
         hx crypto add -alias <alias> -import <file> [-pass <password>]

       Options:
         -alias  <alias> Add the private key + certificate chain with this alias
         -priv   <file>  PEM-encoded private key
         -certs  <file>  PEM-encoced certificate chain
         -import <file>  Import the private key and certificate chain from the
                         given key store file. The private key and certificate
                         should be the only entries in the key store. Supports
                         key stores with .jks, .p12, .pfx, and .fks extensions.
         -pass   <pass>  If the imported file is password protected, you can
                         specify the password with this option.
       ")
    Env.cur.exit(1)
  }

  private Void usageTrust(Str? err := null, OutStream out := Env.cur.out)
  {
    if (err != null) this.err(err)
    out.printLine(
      "Trust:
         hx crypto trust (-cert <file> | -uri <uri>) [-alias <alias>] [-f]

       Options:
         -cert   <file>  PEM-encoded X.509 certificate to trust. If there
                         are multiple certificates in the file they will
                         all be added.
         -uri    <uri>   Trust the entire certificate chain for the given uri.
         -alias  <alias> Add the trusted certificate with this alias.
                         (default: subject's CN)
         -force, -f      Add the certficiate even if the alias already exists
       ")
    Env.cur.exit(1)
  }

  private Void usageExport(Str? err := null, OutStream out := Env.cur.out)
  {
    if (err != null) this.err(err)
    out.printLine(
      "Export:
         hx crypto export -alias <alias>

       Options:
         -alias <alias> the alias of the entry to export
       ")
    Env.cur.exit(1)
  }

  private Void usageList(Str? err := null, OutStream out := Env.cur.out)
  {
    if (err != null) this.err(err)
    out.printLine(
      "List:
         hx crypto list [-alias <alias>]

       Options:
         -alias <alias> List information only for alias
       ")
    Env.cur.exit(1)
  }

  private Void usageRemove(Str? err := null, OutStream out := Env.cur.out)
  {
    if (err != null) this.err(err)
    out.printLine(
      "List:
         hx crypto remove -alias <alias>

       Options:
         -alias <alias> The alias of the entry to remove
       ")
    Env.cur.exit(1)
  }

  private Void usageRename(Str? err := null, OutStream out := Env.cur.out)
  {
    if (err != null) this.err(err)
    out.printLine(
      "Rename:
         hx crypto rename -alias <alias> -to <new alias> [-f] [-keep]

       Options:
         -alias <alias> The alias you want to rename
         -to <alias>    The new alias you want to use for that entry
         -force, -f     Force the rename even if an entry with the 'to'
                        alias already exists.
         -keep          Keep the original entry instead of removing it.
       ")
    Env.cur.exit(1)
  }

}
