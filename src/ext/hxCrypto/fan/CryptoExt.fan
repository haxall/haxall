//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    3 Jan 2016  Brian Frank       Creation
//   31 Aug 2021  Matthew Giannini  Refactor for new Fantom crypto APIs
//    9 Sep 2021  Brian Frank       Refactor for Haxall
//

using crypto
using inet
using haystack
using hx

using [java] java.lang::System

**
** Cryptographic certificate and key pair management
**
const class CryptoExt : ExtObj, ICryptoExt
{
//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make()
  {
    this.dir      = proj.dir.plus(`crypto/`).create
    this.keystore = CryptoKeyStore(proj.exts.actorPool, dir, log, actorTimeout)
  }

  private Duration actorTimeout()
  {
    val := rec.get("actorTimeout") as Number
    if (val != null && val.isDuration) return val.toDuration
    return 1min
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Directory for crypto keystore file
  const File dir

//////////////////////////////////////////////////////////////////////////
// HxCryptoService
//////////////////////////////////////////////////////////////////////////

  ** The keystore to store all trusted keys and certificates
  override const CryptoKeyStore keystore

  ** Get a keystore containing only the key aliased as "https".
  override KeyStore? httpsKey(Bool checked := true)
  {
    entry  := keystore.get("https", false) as PrivKeyEntry
    if (entry != null)
    {
      // create a single-entry keystore
      return Crypto.cur.loadKeyStore.set("https", entry)
    }
    if (checked) throw ArgErr("https key not found")
    return null
  }

  ** The host specific public/private key pair.
  override KeyPair hostKeyPair() { hostKey.keyPair }

  ** The host specific private key and certificate
  override PrivKeyEntry hostKey() { keystore.hostKey }

  ** Read the keystore into a Buf.
  override Buf readBuf() { keystore.readBuf }

  ** Overwrite the contents of the keystore on disk with the contents of this Buf.
  override Void writeBuf(Buf buf) { keystore.writeBuf(buf) }

//////////////////////////////////////////////////////////////////////////
// Lifecycle
//////////////////////////////////////////////////////////////////////////

  override Void onStart()
  {
    // crypto dir gets deleted in test mode, so use jvm truststore for tests
    if (sys.config.isTest) return

    // set the default truststore to use for all sockets
    SocketConfig.setCur(SocketConfig {
      it.truststore = this.keystore
    })

    // Set default trust store for native java apis (e.g. ldap)
    System.setProperty("javax.net.ssl.trustStoreType", "pkcs12")
    System.setProperty("javax.net.ssl.trustStore", keystore.file.osPath)
    System.setProperty("javax.net.ssl.trustStorePassword", "changeit")
  }
}

