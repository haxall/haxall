//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    1 Sep 2021  Matthew Giannini  Creation
//

using concurrent
using crypto
using haystack
using hx

**
** CryptoKeyStore saves itself to file after every modification
**
const class CryptoKeyStore : KeyStore
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(ActorPool pool, File dir, Log log, Duration timeout := 1min)
  {
    this.file     = toFile(dir)
    this.log      = log
    this.timeout  = timeout
    this.actor    = Actor(pool) |Obj? msg->Obj?| { onReceive(msg) }
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

  private static const Str Jvm := "jvm\$"
  private const Log log
  private const Duration timeout
  private const Actor actor
  private const KeyStore keystore

//////////////////////////////////////////////////////////////////////////
// Init
//////////////////////////////////////////////////////////////////////////

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

  static File toFile(File dir)
  {
    dir.plus(`keystore.p12`)
  }

//////////////////////////////////////////////////////////////////////////
// CryptoKeyStore
//////////////////////////////////////////////////////////////////////////

  ** Backup the keystore file
  @NoDoc File backup()
  {
    actor.send(HxMsg("backup")).get(timeout)
  }

  ** Get the Host key pair
  PrivKeyEntry hostKey()
  {
    keystore.get("host", true)
  }

  ** Read the keystore into a Buf.
  Buf readBuf()
  {
    actor.send(HxMsg("readBuf")).get(timeout)
  }

  ** Overwrite the contents of the keystore on disk with the contents of this Buf.
  This writeBuf(Buf buf)
  {
    actor.send(HxMsg("writeBuf", buf)).get(timeout)
  }

//////////////////////////////////////////////////////////////////////////
// KeyStore
//////////////////////////////////////////////////////////////////////////

  override Str format() { keystore.format }

  override Str[] aliases() { keystore.aliases }

  override Int size() { keystore.size }

  override KeyStoreEntry? get(Str alias, Bool checked := true) { keystore.get(alias, checked) }

  override Void save(OutStream out, Str:Obj options := [:])
  {
    actor.send(HxMsg("save", Unsafe(out), options)).get(timeout)
  }

  override This setPrivKey(Str alias, PrivKey priv, Cert[] chain)
  {
    actor.send(HxMsg("set", alias, priv, chain)).get(timeout)
  }

  override This setTrust(Str alias, Cert cert)
  {
    actor.send(HxMsg("set", alias, cert)).get(timeout)
  }

  override This set(Str alias, KeyStoreEntry entry)
  {
    actor.send(HxMsg("set", alias, entry)).get(timeout)
  }

  override Void remove(Str alias)
  {
    actor.send(HxMsg("set", alias)).get(timeout)
  }

//////////////////////////////////////////////////////////////////////////
// Actor
//////////////////////////////////////////////////////////////////////////

  private Obj? onReceive(Obj? obj)
  {
    msg := obj as HxMsg
    switch (msg?.id)
    {
      case "backup":   return onBackup
      case "readBuf":  return file.readAllBuf
      case "writeBuf": return onWriteBuf(msg.a)
      case "save":     return onSave(((Unsafe)msg.a).val, msg.b)
      case "set":      return onSet(msg)
    }
    throw ArgErr("Unexpected message: $obj")
  }

  private File onBackup()
  {
    backupFile := file.plus(`${file.basename}-bkup.${file.ext}`)
    file.copyTo(backupFile, ["overwrite":true])
    return backupFile
  }

  private This onSave(OutStream out, Str:Obj options)
  {
    keystore.save(out, options)
    return this
  }

  ** Load the keystore directly into memory and save it to disk
  private This onWriteBuf(Buf buf)
  {
    // load keystore from buf
    bufKeyStore := Crypto.cur.loadKeyStore(buf.toFile(`onWrite.p12`))

    // clear contents of current keystore
    keystore.aliases.each |alias| { keystore.remove(alias) }

    // copy buf keystore into our keystore
    bufKeyStore.aliases.each |alias| { keystore.set(alias, bufKeyStore.get(alias)) }

    // ensure the buf keystore is also written to disk
    // (do not use autosave because it will cause different bytes to be written,
    //  instead we use the bytes directly as given to us)
    out := file.out
    try { out.writeBuf(buf) }
    finally { out.close }

    return this
  }

  private This onSet(HxMsg msg)
  {
    alias := (Str)msg.a
    if (msg.b == null) keystore.remove(alias)
    else if (msg.b is PrivKey) keystore.setPrivKey(alias, msg.b, msg.c)
    else if (msg.b is Cert) keystore.setTrust(alias, msg.b)
    else if (msg.b is KeyStoreEntry) keystore.set(alias, msg.b)
    else throw ArgErr("$msg")

    return autosave
  }

  ** Save the in-memory keystore back to disk
  private This autosave()
  {
    out := file.out
    try { return onSave(out, [:]) } finally { out.close }
  }
}
