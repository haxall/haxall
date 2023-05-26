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
using haystack
using axon
using hx

**
** Axon functions for crypto library
**
const class CryptoFuncs
{

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  ** Generate a self-signed certificate and store it in the keystore with
  ** the given alias. A new 2048-bit RSA key will be generated and
  ** then self-signed for the given subject DN. The following options
  ** are supported for configuring the signing:
  **   - 'notBefore' (Date): the start date for certificate validity period (default=today)
  **   - 'notAfter' (Date): the end date for the certificate validity period (default=today+365day)
  **
  ** This func will throw an error if an entry with the given alias already exists.
  @Axon { su = true }
  static Obj? cryptoGenSelfSignedCert(Str alias, Str subjectDn, Dict opts := Etc.emptyDict)
  {
    if (ks.containsAlias(alias)) throw ArgErr("An entry already exists with alias ${alias.toCode}")

    // generate self-signed certificate
    crypto := Crypto.cur
    keys   := crypto.genKeyPair("RSA", 2048)
    csr    := crypto.genCsr(keys, subjectDn)
    cert   := crypto.certSigner(csr)
      .notBefore(opts["notBefore"] ?: Date.today)
      .notAfter(opts["notAfter"] ?: Date.today + 365day)
      .basicConstraints
      .sign

    // store in keystore
    ks.setPrivKey(alias, keys.priv, [cert])

    return alias
  }

//////////////////////////////////////////////////////////////////////////
// Internal
//////////////////////////////////////////////////////////////////////////

  ** Read keystore as a grid
  @NoDoc @Axon { su = true }
  static Grid cryptoReadAllKeys()
  {
    aliases := ks.aliases.sort
    rows    := Dict[,]
    aliases.each |alias|
    {
      entry := ks.get(alias)
      row   := entryToRow(entry, alias)
      if (row != null) rows.add(row)
    }
    return Etc.makeDictsGrid(null, rows)
  }

  ** Add certificate chain for a URI to the trust store.
  ** Dict must define 'alias' Str and 'uri' URI.
  @NoDoc @Axon { su = true }
  static Grid cryptoTrustUri(Obj dict)
  {
    rec   := Etc.toRec(dict)
    alias := toAlias(rec->alias)
    uri   := (Uri)rec->uri

    if (alias.isEmpty) alias = Buf.random(6).toBase64Uri
    certs := Crypto.cur.loadCertsForUri(uri)

    aliases := Str:Cert[:]
    certs.each |cert, i|
    {
      entryAlias := i == 0 ? alias : "${alias}.${i}"
      if (ks.containsAlias(entryAlias))
        throw ArgErr("Entry with alias '$entryAlias' already exists.")
      aliases[entryAlias] = cert
    }

    rows := Dict[,]
    aliases.each |cert, entryAlias|
    {
      ks.setTrust(entryAlias, cert)
      entry := ks.get(entryAlias)
      rows.add(entryToRow(entry, entryAlias))
    }

    return Etc.makeDictsGrid(null, rows)
  }

  ** Delete a list of entries
  @NoDoc @Axon { su = true }
  static Obj? cryptoEntryDelete(Obj? aliases)
  {
    toAliases(aliases).each |alias| { ks.remove(alias) }
    return null
  }

  ** Rename a key
  @NoDoc @Axon { su = true }
  static Obj? cryptoEntryRename(Obj dict)
  {
    rec   := Etc.toRec(dict)
    alias := toAlias(rec->alias)
    from  := toAlias(rec.id)
    entry := ks.get(from, false) ?: throw Err("Entry with alias '$from' not found")
    if (ks.containsAlias(alias) && !rec["force"]) throw Err("Entry with alias $alias already exists. Use force option to overwrite.")
    ks.set(alias, entry)
    if (!rec["keep"]) ks.remove(from)
    return alias
  }

  @NoDoc @Axon
  static Grid  cryptoShowPub(Obj obj)
  {
    alias := toAlias(obj)
    entry := ks.get(alias)
    buf   := StrBuf()
    Cert[] certs := entry is TrustEntry ? [entry->cert] : entry->certChain

    certs.each |cert|
    {
      buf.add(cert.toStr)
    }

    return Etc.makeMapGrid(["view":"text"], ["val":buf.toStr])
  }

  ** Add a private key and cert chain entry
  @NoDoc @Axon { su = true }
  static Obj? cryptoAddCert(Str alias, Str pem)
  {
    crypto := Crypto.cur
    PrivKey? privKey := null
    Cert[] chain := [,]
    in := pem.in
    while (true)
    {
      entry := crypto.loadPem(in)
      if (entry == null) break
      else if (entry is PrivKey) privKey = entry
      else chain.add(entry)
    }
    if (privKey == null) throw Err("No private key in ${alias} PEM file")
    if (chain.isEmpty) throw Err("No certificate chain in ${alias} PEM file")
    ks.setPrivKey(alias, privKey, chain)
    return alias
  }

  private static Dict? entryToRow(KeyStoreEntry entry, Str? alias := null)
  {
    tags := Str:Obj["cryptoEntry": Marker.val]

    Cert? cert := null
    if (alias != null)
    {
      tags["id"]    = aliasToId(alias)
      tags["alias"] = alias
    }
    if (entry is PrivKeyEntry)
    {
      keyEntry := (PrivKeyEntry)entry
      cert = keyEntry.certChain.first
      tags["bundle"] = Marker.val
    }
    else if (entry is TrustEntry)
    {
      cert = ((TrustEntry)entry).cert
      tags["trusted"] = Marker.val
    }
    else throw ArgErr("Unrecognized entry: ${entry.typeof}")

    // add cert tags
    tags["subject"]  = cert.subject
    tags["issuer"]   = cert.issuer
    tags["certType"] = cert.certType
    try
    {
      tags["notBefore"] = cert->notBefore
      tags["notAfter"]  = cert->notAfter
    }
    catch (Err ignore) { }

    return Etc.makeDict(tags)
  }

  ** Convert Str alias to an Ref id
  private static Ref aliasToId(Str alias)
  {
    Ref(alias.toBuf.toBase64Uri, alias)
  }

  ** Coerce value to an alias
  private static Str toAlias(Obj? val)
  {
    if (val is Str) return val
    if (val is Ref) return Buf.fromBase64(((Ref)val).id).readAllStr
    throw ArgErr("Cannot coerce val to alias str: $val [${val?.typeof}]")
  }

  ** Coerce list of values to list of aliases
  private static Str[] toAliases(Obj val)
  {
    if (val is Grid) return toAliases(((Grid)val).ids)
    if (val is List) return ((Obj?[])val).map |x->Str| { toAlias(x) }
    return [toAlias(val)]
  }

  ** Convenience to get keystore from context
  private static KeyStore ks()
  {
    HxContext.curHx.rt.services.crypto.keystore
  }
}