//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    1 Sep 2021  Matthew Giannini  Creation
//

using concurrent
using crypto

**
** CryptoKeyStore saves itself to file after every modification
**
const class CryptoKeyStore : KeyStore
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(ActorPool pool, File dir, Log log)
  {
    this.file = toFile(dir)
    this.log = log
    this.actor = Actor.makeCoalescing(pool, null, null) |Obj? msg->Obj?|
    {
      // this actor just handles autosave
      out := file.out
      try { save(out) } finally { out.close }
      return file
    }
    this.keystore = Crypto.cur.loadKeyStore(file.exists ? file : null)

    // initialize
    updatedJvm  := initJvm
    updatedHost := initHostKey
    updated := updatedJvm || updatedHost

    // save and backup
    if (updated) autosave
    backup
  }

  ** Backing file for the keystore
  const File file

  ** Backup the keystore file
  private Void backup()
  {
    backupFile := file.plus(`${file.basename}-bkup.${file.ext}`)
    file.copyTo(backupFile, ["overwrite":true])
  }

  ** Map current JVM keys into my trust store
  ** Return if keystore updated
  private Bool initJvm()
  {
    // load any new system JVM certs into the keystore
    jvmFile := findJvmCerts
    if (!jvmFile.exists)
    {
      log.warn("Could not find JVM trusted certs file")
      return false
    }

    // In Java 9+ the trusted certs file is in p12 format; prior to that it was jks.
    opts   := Str:Obj[:]
    format := Env.cur.vars["java.version"].startsWith("1.") ? "jks" : "pkcs12"
    opts["format"] = format

    // check system property for keystore password
    pwd  := Env.cur.vars["javax.net.ssl.keyStorePassword"]
    if (pwd != null) opts["password"] = pwd

    // begin by assuming all existing jvm certs are untrusted
    untrusted := Str:Str[:] { caseInsensitive = true }
    keystore.aliases.each |alias|
    {
      if (alias.startsWith(Jvm)) untrusted[alias] = alias
    }

    updated := false
    jvm  := Crypto.cur.loadKeyStore(jvmFile, opts)
    jvm.aliases.each |alias|
    {
      entry    := jvm.get(alias)
      jvmAlias := "${Jvm}${alias}"
      // check if we need to add a new trusted certificate
      if (!this.keystore.containsAlias(jvmAlias))
      {
        log.debug("Loading JVM keystore entry: $alias")
        updated = true
        keystore.set(jvmAlias, entry)
      }
      // mark that we still trust the entry with this alias
      untrusted.remove(jvmAlias)
    }

    // remove any certificates that are no longer trusted by the JVM
    if (!untrusted.isEmpty)
    {
      untrusted.each |alias|
      {
        log.info("Removing certifcate no longer trusted by the JVM: $alias")
        keystore.remove(alias)
      }
      updated = true
    }

    return updated
  }

  ** Find the JVM trusted certificates file
  static File findJvmCerts()
  {
    securityDir := File.os(Env.cur.vars["java.home"]) + `lib/security/`
    f := securityDir + `jssecacerts`
    if (!f.exists)
      f = securityDir + `cacerts`
    return f
  }

  ** Create the "host" key pair if not defined
  ** Return if keystore updated
  private Bool initHostKey()
  {
    entry := keystore.get("host", false) as PrivKeyEntry
    if (entry != null) return false

    // generate host key self-signed certificate
    pair := Crypto.cur.genKeyPair("RSA", 2048)
    csr  := Crypto.cur.genCsr(pair, "cn=skyarc.host")
    cert := Crypto.cur.certSigner(csr).sign
    entry = keystore.setPrivKey("host", pair.priv, [cert]).getPrivKey("host")
    return true
  }

//////////////////////////////////////////////////////////////////////////
// KeyStore
//////////////////////////////////////////////////////////////////////////

  override Str format() { keystore.format }

  override Str[] aliases() { keystore.aliases }

  override Int size() { keystore.size }

  override Void save(OutStream out, Str:Obj options := [:]) { keystore.save(out, options) }

  override KeyStoreEntry? get(Str alias, Bool checked := true) { keystore.get(alias, checked) }

  override This setPrivKey(Str alias, PrivKey priv, Cert[] chain)
  {
    keystore.setPrivKey(alias, priv, chain)
    return autosave
  }

  override This setTrust(Str alias, Cert cert)
  {
    keystore.setTrust(alias, cert)
    return autosave
  }

  override This set(Str alias, KeyStoreEntry entry)
  {
    keystore.set(alias, entry)
    return autosave
  }

  override Void remove(Str alias)
  {
    keystore.remove(alias)
    autosave
  }

  PrivKeyEntry hostKey()
  {
    keystore.get("host", true)
  }

  This autosave()
  {
    try
    {
      actor.send("autosave").get(5sec)
    }
    catch (Err err)
    {
      log.err("Failed to save $file", err)
    }
    return this
  }

  static File toFile(File dir)
  {
    dir.plus(`keystore.p12`)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private static const Str Jvm := "jvm\$"
  private const Log log
  private const Actor actor
  private const KeyStore keystore
}


