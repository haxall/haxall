//
// Copyright (c) 2026, SkyFoundry LLC
// All Rights Reserved
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
  ** The response may include Root CA Key Update certificates:
  **  - OldWithOld, OldWithNew, NewWithOld (RFC 4210 Section 4.4)
  **
  ** If bootstrapMode is enabled, this performs bootstrap distribution
  ** as described in RFC 7030 Section 4.1.1
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

      // Check response status
      if (client.resCode != 200)
        throw Err("CA certificates request failed: HTTP ${client.resCode} ${client.resPhrase}")

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
  ** Enroll for a new certificate
  ** RFC 7030 Section 4.2.1: POST /.well-known/est/simpleenroll
  **
  ** @param subjectName Certificate subject DN (e.g., "CN=device.example.com")
  ** @param alias Keystore alias
  ** @param username Optional HTTP Basic/Digest auth username
  ** @param password Optional HTTP Basic/Digest auth password
  ** @return The issued certificate
  **
  Cert[] simpleEnroll(Str subjectName, Str alias, Dict opts := EmptyDict())
  {
    uri := buildOperationUri("simpleenroll")

    username := (opts["username"] as Str)?.trimToNull != null ? (Str)opts["username"] : null
    password := opts["password"] is Dict ? (Str)((Dict)opts["password"])->secret : null

    log.info("Enrolling certificate ($subjectName) using EST Server: $uri")

    client := createHttpClient(uri)
    // Add authentication if provided
    if (username != null && password != null)
      client.authBasic(username, password)

    try
    {
      pair    := Crypto.cur.genKeyPair("RSA", 2048)
      alg     := "sha512WithRSAEncryption"
      csr     := Crypto.cur.genCsr(pair, subjectName, ["algorithm": alg, "subjectAltNames": opts["subjectAltNames"]])

      chain   := enroll(client, csr)
      installCert(alias, pair, chain)
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
  ** Re-enroll (renew/rekey) an existing certificate
  ** RFC 7030 Section 4.2.2: POST /.well-known/est/simplereenroll
  **
  ** The CSR Subject and SubjectAltName MUST match the current certificate
  ** unless ChangeSubjectName attribute is used.
  **
  ** @param alias Keystore alias
  ** @return The reissued certificate
  **
  Cert[] simpleReenroll(Str alias, Dict opts := EmptyDict())
  {
    uri := buildOperationUri("simplereenroll")

    log.info("Re-enrolling certificate at: $uri")

    // Get a keystore containing the client certificate for this connection
    entry     := ks.get(alias) as PrivKeyEntry
    existing  := Crypto.cur.loadKeyStore.set("estClient", entry)

    socketConfig := SocketConfig.cur.copy {
      it.keystore = existing
    }

    client := createHttpClient(uri, socketConfig)

    try
    {
      pair    := Crypto.cur.genKeyPair("RSA", 2048)
      sans    := entry.cert.subjectAltNames
      alg     := "sha512WithRSAEncryption"
      csr     := Crypto.cur.genCsr(pair, entry.cert.subject, ["algorithm": alg, "subjectAltNames": sans])
      chain   := enroll(client, csr)

      installCert(alias, pair, chain)
      return chain
    }
    catch (Err e)
    {
      log.err("Simple re-enrollment failed at $uri", e)
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

    client.writeReq
    client.reqOut.writeBuf(csrBuf).close
    client.readRes

    cert := handleEnrollResponse(client)
    return getCaCerts.insert(0, cert)
  }

  private Void installCert(Str alias, KeyPair pair, Cert[] chain)
  {
    d := caLabel == null ? Etc.dict1("server", estServer) :
                            Etc.dict2("server", estServer, "caLabel", caLabel)

    attrs := Str:Str[:]
    attrs["1.3.6.1.4.1.65564.1"] = ZincWriter.valToStr(d)
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

    // HTTP 4xx/5xx: Error
    throw Err("Enrollment failed: HTTP ${client.resCode} ${client.resPhrase}")
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
