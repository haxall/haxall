//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    7 Jul 2026  Ross Schwalm  Creation
//

using crypto
using haystack
using xeto
using hx

**
** Enrollment over Secure Transport (EST) functionality based on RFC 7030
**
const class CryptoEst
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(CryptoExt ext)
  {
    this.ext = ext
  }

  ** CryptoExt
  const CryptoExt ext

  ** Convenience to get keystore
  private KeyStore ks() { ext.keystore }

//////////////////////////////////////////////////////////////////////////
// CA Certificates
//////////////////////////////////////////////////////////////////////////

  **
  ** Get CA certificates from EST server
  **
  ** Parameters:
  **  - server: Uri EST server host
  **  - opts: Optional dict with:
  **      - caLabel: Str CA Label for multiple-CA servers
  **
  ** Each row in the returned grid includes a 'certRole' column with an
  ** RFC 4210 / RFC 7030 role label describing the certificate's function:
  **
  **   Normal chain certs (subject DN != issuer DN):
  **   - "root"         — single self-signed CA root (no rollover underway)
  **   - "intermediate" — intermediate CA cert in the chain
  **   - "endEntity"    — leaf / end-entity cert (not a CA)
  **
  **   CA key-rollover certs (subject DN == issuer DN, RFC 4210 §4.4):
  **   These appear when the CA is in the process of replacing its key pair.
  **   They let already-deployed clients learn to trust the new CA key via
  **   the old one they already trust, without a hard cut-over:
  **   - "oldWithOld"   — existing root: old public key self-signed by old private key
  **   - "newWithNew"   — new root: new public key self-signed by new private key
  **   - "newWithOld"   — new public key cross-signed by the old private key;
  **                      clients that trust the old key can verify this cert and
  **                      thereby begin trusting the new public key
  **   - "oldWithNew"   — old public key cross-signed by the new private key;
  **                      lets clients that already have the new key validate
  **                      signatures/certs that were issued under the old key
  **   - "rollover"     — cert whose subject DN equals its issuer DN (marking it
  **                      as a rollover-family cert) but whose specific role could
  **                      not be resolved.  This happens when:
  **                        (a) only one self-signed root is present so direction
  **                            (NewWithOld vs OldWithNew) cannot be determined, or
  **                        (b) the cert's public key does not match either root,
  **                            or (c) the cert is self-signed but lacks the CA
  **                            basic-constraint (isSelfSigned && !isCA).
  **                      Treat this as informational; the cert is part of a
  **                      rollover bundle but cannot be placed precisely.
  **
  Grid getCaCerts(Uri server, Dict opts := EmptyDict())
  {
    certs := estClient(server, opts["caLabel"]).getCaCerts
    roles := classifyCertRoles(certs)
    rows  := Dict[,]
    certs.each |Cert c|
    {
      row := CryptoFuncs.entryToRow(c)
      if (row != null)
      {
        role := roles.get(c.encoded.toBase64) ?: "unknown"
        row  = Etc.dictSet(row, "certRole", role)
        rows.add(row)
      }
    }

    grid := CryptoFuncs.cryptoStdDisplay(Etc.makeDictsGrid(null, rows))

    if (grid.col("certRole", false) != null)
    {
      cols := grid.colNames
      cols.moveTo("certRole", 2)
      grid = grid.reorderCols(cols)
    }

    return grid
  }

  **
  ** Classify each certificate in the cacerts bundle with an RFC 4210 role label.
  **
  ** Returns a map of cert.encoded.toBase64 → role string so callers can look
  ** up the role for any cert in O(1) after a single pass over the bundle.
  **
  ** Classification algorithm:
  **  1. Collect all certs where (isSelfSigned && isCA) as the "root pool".
  **  2. A cert where subject != issuer is a normal chain cert:
  **       isCA  → "intermediate"
  **       !isCA → "endEntity"
  **  3. A cert where subject == issuer AND (isSelfSigned && isCA) is a genuine
  **     self-signed CA root.  Group by subject DN:
  **       one root for that DN  → "root"
  **       two roots for that DN → CA key rollover in progress; sort by notBefore:
  **         newer = "newWithNew", older = "oldWithOld"
  **  4. A cert where subject == issuer but NOT (isSelfSigned && isCA) is a member
  **     of the RFC 4210 rollover-transition family.  This covers:
  **       (a) Cross-signed transition certs — subject == issuer but signed by the
  **           *other* key, so isSelfSigned is false.  When two roots are present,
  **           compare public keys to assign direction:
  **             cert.pub == newRoot.pub → "newWithOld" (new key, old sig)
  **             cert.pub == oldRoot.pub → "oldWithNew" (old key, new sig)
  **       (b) Self-signed but non-CA certs — isSelfSigned is true yet isCA is
  **           false (basic-constraint CA flag absent).  These appear in some EST
  **           server bundles and share the CA's own DN but are not classifiable as
  **           true roots; they fall through to "rollover".
  **     If the public-key comparison fails or fewer than two roots are present, the
  **     cert is labelled "rollover" — it is clearly part of a rollover bundle but
  **     its exact role cannot be resolved from the available information.
  **
  private Str:Str classifyCertRoles(Cert[] bundle)
  {
    if (bundle.isEmpty) return [:]

    // All self-signed CA roots in the bundle
    Cert[] allRoots := bundle.findAll |c| { c.isSelfSigned && c.isCA }

    Str:Str roles := [:]
    bundle.each |c|
    {
      key := c.encoded.toBase64

      if (c.subject != c.issuer)
      {
        // Normal chain cert — not a CA-self-DN cert
        roles[key] = c.isCA ? "intermediate" : "endEntity"
        return
      }

      // CA-self-DN cert: subject == issuer
      // Find all self-signed roots with this same DN (may be 1 or 2 during rollover)
      Cert[] groupRoots := allRoots.findAll |r| { r.subject == c.subject }

      if (c.isSelfSigned && c.isCA)
      {
        // Self-signed root cert
        if (groupRoots.size <= 1)
        {
          roles[key] = "root"
        }
        else
        {
          // Two roots with the same DN → CA key rollover in progress.
          // Sort by notBefore: newer = NewWithNew, older = OldWithOld.
          sorted := groupRoots.dup.sort |a, b|
          {
            ((Date)a->notBefore).compare(b->notBefore)
          }
          roles[key] = (key == sorted.last.encoded.toBase64) ? "newWithNew" : "oldWithOld"
        }
      }
      else
      {
        // Rollover-family cert: subject == issuer but NOT (isSelfSigned && isCA).
        // Two sub-cases land here:
        //   (a) Cross-signed transition cert — signed by the *other* CA key, so
        //       isSelfSigned is false.  Public-key comparison below identifies direction.
        //   (b) Self-signed but non-CA cert — isSelfSigned is true, isCA is false
        //       (basic-constraint CA flag absent).  Some EST servers include these;
        //       they share the CA's DN but cannot be classified as true roots.
        //       They fall through to the generic "rollover" label below.
        if (groupRoots.size < 2)
        {
          // Cannot distinguish direction without two roots present — label generically.
          roles[key] = "rollover"
          return
        }
        sorted := groupRoots.dup.sort |a, b|
        {
          ((Date)a->notBefore).compare(b->notBefore)
        }
        oldRoot := sorted.first
        newRoot := sorted.last

        oldPubB64  := oldRoot.pub.encoded?.toBase64 ?: ""
        newPubB64  := newRoot.pub.encoded?.toBase64 ?: ""
        certPubB64 := c.pub.encoded?.toBase64 ?: ""

        if      (!certPubB64.isEmpty && certPubB64 == newPubB64) roles[key] = "newWithOld"
        else if (!certPubB64.isEmpty && certPubB64 == oldPubB64) roles[key] = "oldWithNew"
        // Public key didn't match either root (e.g. self-signed non-CA cert, or an
        // unexpected cert from the server) — label generically as rollover-family.
        else roles[key] = "rollover"
      }
    }

    return roles
  }

//////////////////////////////////////////////////////////////////////////
// Enroll
//////////////////////////////////////////////////////////////////////////

  **
  ** Enroll for a new certificate
  **
  ** Parameters:
  **  - dict:
  **      - uri (required): Uri EST server host
  **      - subjectName (required): Str Certificate subject DN (e.g., "CN=device.example.com")
  **      - alias: Str Keystore alias (https if not specified)
  **      - caLabel: Str CA Label for multiple-CA servers
  **      - renewalFreq: Number of days to renew certificate (default 30)
  **      - sanDns: Comma separated DNS name values
  **      - sanIp: Comma separated IP address values
  **      - sanUri: Comma separated Uri values
  **      - sigAlgorithm: Signing algorithm (default "sha256WithRSAEncryption")
  **      - username: Str HTTP auth username
  **      - password: Str HTTP auth password
  **
  Grid enroll(Obj dict)
  {
    rec    := Etc.toRec(dict)
    alias  := rec.has("alias") ? CryptoFuncs.toAlias(rec->alias) : "https"
    server := rec->uri
    subjectName := rec->subjectName
    caLabel := rec.has("caLabel") ? (Str)rec["caLabel"] : ""

    // build subject alternative names from comma-separated tag strings
    sans := San[,]
    if (rec.has("sanDns"))
        ((Str)rec->sanDns).split(',').mapNotNull |v| { v.trimToNull }.each { sans.add(San.dnsName(it)) }
    if (rec.has("sanIp"))
        ((Str)rec->sanIp).split(',').mapNotNull |v| { v.trimToNull }.each { sans.add(San.ipAddr(it)) }
    if (rec.has("sanUri"))
        ((Str)rec->sanUri).split(',').mapNotNull |v| { v.trimToNull }.each { sans.add(San.uri(it)) }

    if (sans.isEmpty)
        throw ArgErr("At least one Subject Alternative Name must be provided (sanDns, sanIp, or sanUri)")

    opts := Etc.dictSet(rec, "subjectAltNames", sans)

    certs := estClient(server, caLabel.trimToNull).simpleEnroll(subjectName, alias, opts)

    cert := certs.first
    msg := """---ENROLLMENT SUCCESSFUL---
              Subject: ${cert.subject}
              Expiration: ${cert->notAfter}

              ${cert.toStr}"""

    return Etc.makeDictGrid(Etc.dict1("view","fandoc"), Etc.dict1("val", msg))
  }

//////////////////////////////////////////////////////////////////////////
// Reenroll
//////////////////////////////////////////////////////////////////////////

  **
  ** Reenroll using existing certificate
  **
  ** Parameters:
  **  - alias: Str Keystore alias
  **
  Grid reenroll(Str alias)
  {
    config := estAliasConfig(alias)
    if (config == null) throw Err("Alias ($alias) not managed by estClient")

    certs := estClient(config["server"], config["caLabel"]).simpleReenroll(alias, config)

    rows := Dict[,]
    certs.each |Cert c|
    {
      row := CryptoFuncs.entryToRow(c)
      if (row != null) rows.add(row)
    }

    return CryptoFuncs.cryptoStdDisplay(Etc.makeDictsGrid(null, rows))
  }

//////////////////////////////////////////////////////////////////////////
// Housekeeping
//////////////////////////////////////////////////////////////////////////

  ** Check the keystore for estManaged keys and renew if required
  Void checkForRenewals()
  {
    // Build the list of estManaged rows directly from the keystore so no
    // Context needs to be installed on the current actor (which is
    // not the case during housekeeping callbacks).
    rows := Dict[,]
    ks.aliases.sort.each |alias|
    {
      entry := ks.get(alias)
      row   := CryptoFuncs.entryToRow(entry, alias)
      if (row != null) rows.add(row)
    }
    estManaged := rows.findAll |k| { k.has("estManaged") }
    estManaged.each |k|
    {
      today       := DateTime.now.date
      expiration  := (Date)k["notAfter"]
      config      := (Dict)k["estManaged"]
      numDays     := (config["renewalFreq"] as Number)?.toInt ?: 30
      renewalFreq := 1day * numDays
      if (expiration.minusDate(today) <= renewalFreq)
      {
        alias  := k["alias"]
        server := config["server"]
        ext.log.info("Renewing certificate ($alias) from EST server: ${server}")
        reenroll(alias)
      }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utilities
//////////////////////////////////////////////////////////////////////////

  ** Get an EST client
  private CryptoEstClient estClient(Uri server, Str? caLabel := null)
  {
    CryptoEstClient(ext, server, caLabel)
  }

  private Bool estManagedAlias(Str alias)
  {
    estAliasConfig(alias) != null
  }

  private Dict? estAliasConfig(Str alias)
  {
    entry := ks.get(CryptoFuncs.toAlias(alias))
    return CryptoFuncs.entryToRow(entry)["estManaged"]
  }
}
