//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Mar 2026  Ross Schwalm  Creation
//

using crypto
using inet
using web
using haystack
using hx
using xeto

**
** EST (Enrollment over Secure Transport) Client Implementation
** Based on RFC 7030
**
** Key EST Operations (RFC 7030):
**  - /cacerts: Distribution of CA Certificates (REQUIRED)
**  - /simpleenroll: Simple Enrollment (REQUIRED)
**  - /simplereenroll: Simple Re-enrollment (REQUIRED)
**
**  NOTE: Each operation has a standard prefix: .well-known/est
**
const class CryptoEstClient
{
  ** EST Server Host
  ** https://{host}/.well-known/est/{operation}
  const Uri estServer

  ** EST Server Standard Prefix
  const Str estOperationPrefix := ".well-known/est"

  ** EST Server Optional CA label
  ** https://{host}/.well-known/est/{caLabel}/{operation}
  const Str? caLabel

  ** CryptoExt
  const CryptoExt crypto

  ** Constructor
  new make(CryptoExt crypto, Uri estServer, Str? caLabel := null)
  {
    this.crypto = crypto
    this.estServer = estServer
    this.caLabel = caLabel
  }

  ** Logger
  private Log log() { crypto.log }

  ** Convenience to get keystore
  private KeyStore ks() { crypto.keystore }

//////////////////////////////////////////////////////////////////////////
// CA Certificates (Section 4.1)
//////////////////////////////////////////////////////////////////////////

  **
  ** Request CA certificates from EST server
  ** RFC 7030 Section 4.1.2: GET /.well-known/est/cacerts
  **
  ** Returns a list of CA certificates in the chain. The first certificate
  ** should be the current root CA certificate. Additional certificates
  ** help build a chain to the root EST CA.
  **
  Cert[] getCaCerts(Bool verify := true)
  {
    // Build URI for /cacerts operation
    uri := buildOperationUri("cacerts")

    debug("Getting CA certificates from: $uri")

    // Create HTTP client with TLS configuration
    client := createHttpClient(uri)

    try
    {
      // Perform GET request
      client.writeReq.readRes

      // Check response status - reads the body for diagnostics on failure
      checkCaCertsResponse(client)

      // Verify content type
      contentType := client.resHeader("Content-Type", false)
      if (contentType == null || !contentType.contains("application/pkcs7-mime"))
        throw Err("Invalid content type for CA certificates response: $contentType")

      base64Str := client.resIn.readAllStr
      pkcs7 := Buf.fromBase64(base64Str)

      // Parse PKCS#7 certs-only message
      certs := parsePkcs7CertsOnly(pkcs7.in)

      debug("Received ${certs.size} CA certificate(s)")

      return certs
    }
    catch (Err e)
    {
      log.err("Failed to get CA certificates from $uri", e)
      throw e
    }
    finally
    {
      client.close
    }
  }

//////////////////////////////////////////////////////////////////////////
// Simple Enrollment (Section 4.2.1)
//////////////////////////////////////////////////////////////////////////

  **
  ** Enroll for a new certificate and return the full certificate chain
  ** RFC 7030 Section 4.2.1: POST /.well-known/est/simpleenroll
  **
  Cert[] simpleEnroll(Str subjectName, Str alias, Dict opts := EmptyDict())
  {
    uri := buildOperationUri("simpleenroll")

    username := (opts["username"] as Str)?.trimToNull != null ? opts["username"] : null
    password := opts["password"] is Dict ? ((Dict)opts["password"])->secret : null

    log.info("Enrolling certificate ($subjectName) using EST Server: $uri")

    client := createHttpClient(uri)
    // Add authentication if provided
    if (username != null && password != null)
      client.authBasic(username, password)

    try
    {
      //Only RSA is supported for generating CSRs today
      //alg     := opts["algorithm"] as Str ?: "RSA"
      alg     := "RSA"
      keySize := (opts["keySize"] as Number)?.toInt ?: 2048
      pair    := Crypto.cur.genKeyPair(alg, keySize)
      sigAlg  := opts["sigAlgorithm"] as Str ?: "sha256WithRSAEncryption"
      csr     := Crypto.cur.genCsr(pair, subjectName, ["algorithm": sigAlg, "subjectAltNames": opts["subjectAltNames"]])
      chain   := enroll(client, csr)
      installCert(alias, pair, chain, opts)
      return chain
    }
    catch (Err e)
    {
      log.err("EST enrollment failed ($subjectName)", e)
      throw e
    }
    finally
    {
      client.close
    }
  }

//////////////////////////////////////////////////////////////////////////
// Simple Re-enrollment (Section 4.2.2)
//////////////////////////////////////////////////////////////////////////

  **
  ** Re-enroll (renew/rekey) an existing certificate and return the full certificate chain
  ** RFC 7030 Section 4.2.2: POST /.well-known/est/simplereenroll
  **
  ** Parameters:
  **  - alias: Keystore alias
  **
  Cert[] simpleReenroll(Str alias, Dict config)
  {
    uri := buildOperationUri("simplereenroll")

    log.info("Re-enrolling certificate (alias ${alias}) at: $uri")

    // Get a keystore containing the client certificate for this connection
    entry     := ks.get(alias) as PrivKeyEntry
    existing  := Crypto.cur.loadKeyStore.set("estClient", entry)
    alg       := entry.priv.algorithm
    keySize   := entry.priv.keySize
    sigAlg    := config["sigAlgorithm"] as Str ?: "sha256WithRSAEncryption"

    socketConfig := SocketConfig.cur.copy {
      it.keystore = existing
    }

    client := createHttpClient(uri, socketConfig)

    try
    {
      pair    := Crypto.cur.genKeyPair(alg, keySize)
      sans    := entry.cert.subjectAltNames
      csr     := Crypto.cur.genCsr(pair, entry.cert.subject, ["algorithm": sigAlg, "subjectAltNames": sans])
      chain   := enroll(client, csr)

      installCert(alias, pair, chain, config)
      return chain
    }
    catch (Err e)
    {
      log.err("Simple re-enrollment (alias ${alias}) failed at $uri", e)
      throw e
    }
    finally
    {
      client.close
    }
  }

  private Cert[] enroll(WebClient client, Csr csr)
  {
    csrStr  := formatCsr(csr)

    // Convert base64 string to buffer as ASCII bytes
    csrBuf := Buf().print(csrStr).flip

    client.reqMethod = "POST"
    client.reqHeaders["Content-Type"] = "application/pkcs10"
    client.reqHeaders["Content-Transfer-Encoding"] = "base64"
    client.reqHeaders["Content-Length"] = csrBuf.size.toStr

    debug("Enrolling CSR: uri=${client.reqUri}, Content-Length=${csrBuf.size}")
    debug("CSR PEM (for inspection):\n${csr.toStr}")

    client.writeReq
    client.reqOut.writeBuf(csrBuf).close
    client.readRes

    cert   := handleEnrollResponse(client)
    bundle := getCaCerts
    return buildIssuanceChain(cert, bundle)
  }

  **
  ** Build the issuance chain for the given end-entity certificate from the
  ** cacerts bundle.  Walks subject/issuer links from the end-entity up to a
  ** self-signed root, filtering out any rollover transition certificates
  ** (OldWithNew / NewWithOld) that share the CA DN but are not part of the
  ** actual issuance path.
  **
  ** When multiple self-signed roots share the same DN (CA key rollover in
  ** progress) the newest root by notBefore date is preferred, since newly
  ** issued certs will be signed by the new CA key.
  **
  ** Throws Err if the chain cannot be completed — e.g. the CA rolled its
  ** key between the enrollment request and the /cacerts fetch, so the
  ** issued cert's issuer is no longer represented.  Callers should retry.
  **
  private Cert[] buildIssuanceChain(Cert endEntity, Cert[] bundle)
  {
    chain   := Cert[endEntity]
    current := endEntity
    visited := Str[current.encoded.toBase64]

    while (!current.isSelfSigned)
    {
      if (chain.size > 10)
        throw Err("EST enrollment failed: certificate chain depth exceeded 10 levels")

      issuerDn := current.issuer

      // All bundle certs whose subject matches the current issuer DN,
      // excluding certs already in the chain (cycle guard).
      candidates := bundle.findAll |c|
      {
        c.subject == issuerDn && !visited.contains(c.encoded.toBase64)
      }

      if (candidates.isEmpty)
        throw Err(
          "EST enrollment failed: cannot build issuance chain from issued cert " +
          "to a trust anchor — no cert found with subject DN '${issuerDn}' in " +
          "the cacerts response.  The CA may be mid key-rollover; retry enrollment.")

      // Prefer self-signed roots over intermediates and cross-signed certs.
      // When two self-signed roots share the same DN (rollover), choose the
      // newest (highest notBefore) since new certs are signed by the new key.
      selfSignedRoots := candidates.findAll |c| { c.isSelfSigned && c.isCA }
      Cert chosen := selfSignedRoots.isEmpty ?
                      candidates.first :
                      selfSignedRoots.max |a, b|
                      {
                        ((Date)a->notBefore).compare(b->notBefore)
                      }

      chain.add(chosen)
      visited.add(chosen.encoded.toBase64)
      current = chosen
    }

    return chain
  }

  private Dict parseConfig(Dict d)
  {
    Etc.dict4x("server", estServer,
               "caLabel", caLabel,
               "sigAlgorithm", d["sigAlgorithm"],
               "renewalFreq", d["renewalFreq"])
  }

  private Void installCert(Str alias, KeyPair pair, Cert[] chain, Dict config)
  {
    attrs := Str:Str[:]
    attrs["1.3.6.1.4.1.65564.1.1"] = ZincWriter.valToStr(parseConfig(config))
    crypto.setKey(alias, pair.priv, chain, attrs)
  }

//////////////////////////////////////////////////////////////////////////
// HTTP/TLS Support
//////////////////////////////////////////////////////////////////////////

  **
  ** Create and configure HTTP client
  **
  private WebClient createHttpClient(Uri uri, SocketConfig? socketConfig := null)
  {
    client := socketConfig == null ?
                WebClient(uri) :
                  WebClient {
                    it.reqUri       = uri
                    it.socketConfig = socketConfig
                  }

    // Set default headers
    client.reqHeaders["User-Agent"] = "SkySpark-EST-Client/1.0"
    client.reqHeaders["Accept"] = "*/*"

    return client
  }

  **
  ** Add HTTP Basic authentication to client
  **
  private Void addBasicAuth(WebClient client, Str username, Str password)
  {
    client.authBasic(username, password)
  }

//////////////////////////////////////////////////////////////////////////
// Response Handling
//////////////////////////////////////////////////////////////////////////

  **
  ** Handle enrollment/re-enrollment response
  ** RFC 7030 Section 4.2.3
  **
  ** Response MUST be a certs-only CMC Simple PKI Response, as defined in RFC5272,
  ** containing only the certificate that was issued
  **
  private Cert handleEnrollResponse(WebClient client)
  {
    // HTTP 200: Success
    if (client.resCode == 200)
    {
      contentType := client.resHeader("Content-Type", false)
      if (contentType == null || !contentType.contains("application/pkcs7-mime"))
        throw Err("Invalid content type for enrollment response: $contentType")

      base64Str := client.resIn.readAllStr
      pkcs7 := Buf.fromBase64(base64Str)
      return parsePkcs7CertsOnly(pkcs7.in).first
    }

    // HTTP 202: Accepted, pending approval
    if (client.resCode == 202)
    {
      retryAfter := client.resHeader("Retry-After", false)
      throw EstPendingErr("Certificate request pending approval. Retry after: $retryAfter")
    }

    // HTTP 4xx/5xx: Error - read the response body for the server's reason
    errBody    := readErrBody(client)
    contentType := client.resHeader("Content-Type", false)
    wwwAuth    := client.resHeader("WWW-Authenticate", false)

    // Build a detailed error message from all available context
    msg := StrBuf()
    msg.add("Enrollment failed: HTTP ${client.resCode} ${client.resPhrase}")
    if (contentType != null) msg.add(" | Content-Type: $contentType")
    if (wwwAuth    != null) msg.add(" | WWW-Authenticate: $wwwAuth")
    if (errBody    != null) msg.add(" | Server response: $errBody")

    log.err(msg.toStr)
    throw Err(msg.toStr)
  }

  **
  ** Safely read the response body for error reporting (max 2048 chars).
  ** Returns null if the body is empty, unreadable, or binary.
  **
  private Str? readErrBody(WebClient client)
  {
    try
    {
      body := client.resIn.readAllStr
      if (body.isEmpty) return null
      // truncate to avoid flooding the log
      return body.size > 2048 ? body[0..<2048] + "..." : body
    }
    catch (Err e)
    {
      // Body may already be consumed or be non-text — just ignore
      return null
    }
  }

//////////////////////////////////////////////////////////////////////////
// Parsing
//////////////////////////////////////////////////////////////////////////

  **
  ** Parse PKCS#7 certs-only message
  ** RFC 7030 Section 4.1.3: Response is PKCS#7 certs-only with base64 encoding
  **
  private Cert[] parsePkcs7CertsOnly(InStream in)
  {
    try
    {
      return Crypto.cur.loadX509(in)
    }
    catch (Err e)
    {
      log.err("Failed to parse PKCS#7 certificates", e)
      throw Err("Invalid PKCS#7 certificate format", e)
    }
  }

  **
  ** Check a non-200 response in getCaCerts and log the body
  **
  private Void checkCaCertsResponse(WebClient client)
  {
    if (client.resCode == 200) return
    errBody := readErrBody(client)
    msg := "CA certificates request failed: HTTP ${client.resCode} ${client.resPhrase}"
    if (errBody != null) msg += " | Server response: $errBody"
    throw Err(msg)
  }

//////////////////////////////////////////////////////////////////////////
// Utilities
//////////////////////////////////////////////////////////////////////////

  **
  ** Build operation URI
  **
  private Uri buildOperationUri(Str operation)
  {
    caLabel == null ?
      estServer.plusSlash.plus(estOperationPrefix.toUri).plusSlash.plus(operation.toUri) :
      estServer.plusSlash.plus(estOperationPrefix.toUri).plusSlash.plus(caLabel.toUri).plusSlash.plus(operation.toUri)
  }

  **
  ** Format CSR in single line format
  **
  private Str formatCsr(Csr csr)
  {
    // Extract base64 content from PEM format and remove all whitespace/newlines
    // EST servers expect clean base64 DER encoding without PEM headers or newlines
    csrPem := csr.toStr
    return csrPem
      .replace("-----BEGIN CERTIFICATE REQUEST-----", "")
      .replace("-----END CERTIFICATE REQUEST-----", "")
      .replace("\n", "")
      .replace("\r", "")
      .trim
  }

  **
  ** Debug logging
  **
  private Void debug(Str msg, Err? err := null)
  {
    if (log.isDebug) log.debug(msg, err)
  }
}

**************************************************************************
** EstPendingErr
**************************************************************************

**
** Exception thrown when certificate request is pending (HTTP 202)
**
const class EstPendingErr : Err
{
  new make(Str msg := "", Err? cause := null) : super(msg, cause) {}
}

