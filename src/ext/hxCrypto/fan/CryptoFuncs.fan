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
using xeto
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

  @NoDoc @Axon { su = true }
  static Grid cryptoLocal(Str? type)
  {
    //cx := Context.cur
    t := type ?: "all"
    f := ""
    switch(type)
    {
      case "cryptoTrust":     f = "trusted"
      case "cryptoPrivKey":   f = "bundle"
      case "all":
      default:                f = "cryptoEntry"
    }
    return cryptoReadAllKeys.filter(Filter.fromStr(f))
  }

  @NoDoc @Axon { su = true }
  static Grid cryptoCheckAction(Obj dict)
  {
    Uri uri := ``
    if (dict is Uri) uri = dict
    else if (dict is Grid) uri = Etc.toRec(dict)["uri"]
    else if (dict is Dict) uri = ((Dict)dict)["uri"]
    else if (dict is Str) uri = Uri.fromStr(dict)
    else throw ArgErr("Invalid input: $dict")

    return cryptoCheckUri(uri).addMeta(Etc.dict1("view", "table"))
  }

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

    keys := Etc.makeDictsGrid(null, rows)

    return cryptoStdDisplay(keys)
  }

  ** Add certificate chain for a URI to the trust store.
  ** Dict must define 'alias' Str and 'uri' URI.
  @NoDoc @Axon { su = true }
  static Grid cryptoTrustUri(Obj dict)
  {
    rec   := Etc.toRec(dict)
    alias := toAlias(rec->alias)
    uri   := (Uri)rec->uri
    check := rec.has("check")

    if (alias.isEmpty) alias = Buf.random(6).toBase64Uri
    rawCerts := Crypto.cur.loadCertsForUri(uri)

    certs := sortRootToEndEntity(rawCerts)

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
      if (!check && (cert.isCA || cert.isSelfSigned))
      {
        ks.setTrust(entryAlias, cert)
        entry := ks.get(entryAlias)
        rows.add(entryToRow(entry, entryAlias))
      }
      else rows.add(entryToRow(cert, entryAlias))
    }

    return Etc.makeDictsGrid(null, rows)
  }

  ** Retrieve certificate chain for a URI without adding to trust store.
  @NoDoc @Axon { su = true }
  static Grid cryptoCheckUri(Uri uri)
  {
    opts := Etc.dict3("alias", "check",
                      "uri", uri,
                      "check", Marker.val)

    chain := cryptoTrustUri(opts).sortCol("alias")

    return cryptoStdDisplay(chain)
  }

  ** Display crypto grids with an easier to read standard column order
  @NoDoc
  private static Grid cryptoStdDisplay(Grid input)
  {
    cols := input.colNames
    preferredOrder := ["id", "alias", "ca", "selfSigned", "notAfter", "keyAlg", "keySize", "subject", "issuer"]
    sorted := preferredOrder.intersection(cols)
    sorted.each |c, i| { cols = cols.moveTo(c, i)}

    hidden := Etc.dict1("hidden", Marker.val)

    return input.reorderCols(cols).addColMeta("id", hidden)
  }

  ** Attempt to sort the certificate chain from Root to End Entity.
  **
  ** Certificates that are not part of the chain are put after the End Entity.
  **
  ** If unable to complete the chain, then certificates are returned in
  ** the order they were provided
  @NoDoc
  private static List sortRootToEndEntity(List serverCerts)
  {
    if (serverCerts.size == 1) return serverCerts

    roots := serverCerts.findAll |Cert c->Bool| { return c.isCA && c.isSelfSigned }

    if (roots.size == 0 || roots.size > 1) return serverCerts

    serverCerts.removeAll(roots)
    Cert rootCA := roots[0]
    chain := [rootCA]
    certsNotInChain := [,]

    if (serverCerts.size > 0)
    {
      endEntitys := serverCerts.findAll |Cert c->Bool| { return !c.isCA && !c.isSelfSigned }

      if (endEntitys.size == 0 || endEntitys.size > 1) return serverCerts

      serverCerts.removeAll(endEntitys)
      Cert endEntity := endEntitys[0]

      if (serverCerts.size > 0)
      {
        intermediateCAs := Cert[,]
        Cert? ca := serverCerts.find |Cert c->Bool| { return c.subject == endEntity.issuer }
        count := 0
        while (ca != null && count < 10)
        {
          intermediateCAs.insert(0, ca)
          serverCerts.remove(ca)
          count++
          ca = serverCerts.find |Cert c->Bool| { return c.subject == ca.issuer }
        }
        if (serverCerts.size > 0) certsNotInChain = serverCerts
        if (endEntity.issuer != rootCA.subject && intermediateCAs[0].issuer != rootCA.subject) return serverCerts
        chain.addAll(intermediateCAs)
      }
      else
      {
        if (endEntity.issuer != rootCA.subject) return serverCerts
      }

      chain.add(endEntity)
      chain.addAll(certsNotInChain)
    }

    return chain
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

  ** Add a private key and cert chain entry.
  ** Can also trust a single certificate if no priv key is supplied.
  @NoDoc @Axon { su = true }
  static Obj? cryptoAddCert(Str alias, Str pem, Bool force := false)
  {
    alias = toAlias(alias)
    if (ks.containsAlias(alias) && !force) throw Err("Entry with alias $alias already exists. Use force option to overwrite.")
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

    if (privKey == null)
    {
      // trust a single cert
      if (chain.size != 1) throw Err("Must provide a single certificate to trust")
      ks.setTrust(alias, chain.first)
    }
    else
    {
      // add public/private key certificate chain
      if (chain.isEmpty) throw Err("No certificate chain in ${alias} PEM file")
      ks.setPrivKey(alias, privKey, chain)
    }
    return alias
  }

  private static Dict? entryToRow(Obj entry, Str? alias := null)
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
    else if (entry is Cert)
    {
      cert = entry
      tags["pem"] = cert.toStr
      if (cert.isSelfSigned) tags["selfSigned"] = Marker.val
      if (cert.isCA) tags["ca"] = Marker.val
    }
    else throw ArgErr("Unrecognized entry: ${entry.typeof}")

    // add cert tags
    tags["subject"]  = cert.subject
    tags["issuer"]   = cert.issuer
    tags["certType"] = cert.certType
    try
    {
      key := cert.pub
      tags["notBefore"] = cert->notBefore
      tags["notAfter"]  = cert->notAfter
      tags["keyAlg"] = key.algorithm
      tags["keySize"] = Number.makeInt(key.keySize).toLocale("#")
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
    if (val is Str)
    {
      if (((Str)val).trimToNull == null) throw Err("Alias cannot be empty")
      return val
    }
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
    Context.cur.sys.crypto.keystore
  }
}

