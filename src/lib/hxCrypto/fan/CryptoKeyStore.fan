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
internal const class CryptoKeyStore : KeyStore
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(ActorPool pool, File file, Log log)
  {
    this.file = file
    this.log = log
    this.actor = Actor.makeCoalescing(pool, null, null) |Obj? msg->Obj?|
    {
      // this actor just handles autosave
      out := file.out
      try { save(out) } finally { out.close }
      return file
    }
    this.keystore = Crypto.cur.loadKeyStore(file.exists ? file : null)
    loadJvm
  }

  private Void loadJvm()
  {
    // load any new system JVM certs into the keystore
    jvmFile := findJvmCerts
    if (!jvmFile.exists)
    {
      log.warn("Could not find JVM trusted certs file")
      return
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

    // autosave if any changes were made
    if (updated) this.autosave
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

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private static const Str Jvm := "jvm\$"
  private const File file
  private const Log log
  private const Actor actor
  private const KeyStore keystore
}


