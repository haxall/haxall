<!--
title:      Cryptography
author:     Matthew Giannini
created:    15 Feb 2022
copyright:  Copyright (c) 2016, SkyFoundry LLC, All Rights Reserved
license:    Licensed under the Academic Free License version 3.0
-->

# Overview
This chapter covers cryptography and management of TLS keys and certificates.

# Crypto Tool
Use the `crypto` command of the `hx` tool to manage your key and trust store offline.
The following sections demonstrate how to use this tool for various common tasks. To run the
`crypto` command do:

```
# List all available crypto actions
hx crypto
```

All the `crypto` actions allow you to specify the directory for your
installation. This directory contain the `crypto/` directory for your installation.

```
hx crypto <action> -d ./path/to/dir/
```

# HTTPS
To configure Haxall to serve HTTPS connections, you must first add your
server's private key and certificate chain to the crypto keystore, and you
**must** add them to the keystore using alias `https`. You should use the
`crypto` tool for this:

```
  // Get help on adding entries to the skyarc key store
  hx crypto add -help

  // Option 1) Import the private key and certificate from an existing key store
  // (p12, pfx, jks)
  hx crypto add -alias https -import keystore.p12

  // If the store is password protected, use the -pass option to specify the password
  // NOTE: the terminal/command prompt may interpret certain special characters in your
  // password in a way that the import will fail indicating an incorrect password
  // was entered. If this happens, change the password on the p12 file to something
  // containing only alpha-numeric characters and try again.
  hx crypto add -alias https -import keystore.p12 -pass "password"

  // Option 2) Import the private key and certificate chain explicitly
  hx crypto add -alias https -priv private_key.pem -certs publicCertChain.pem
```

If you need to update your https certificate you can run the command again
and it will overwrite the entry with alias `https` in the keystore.

After adding the https entry to the keystore, you need to enable https for
Haxall by editing the `http` ext rec to turn on https and specify the https port:

    diff(read(ext == "http"), {httpsEnabled:true, httpsPort:8443}).commit

If you are using SkySpark you can enable and configure HTTPS from the HTTP settings
view for the host.

A restart is required to enable https. If everything is configured correctly you
will see log messages similar to this in the console

    [2016-06-09 09:03:12] <web> {} [info] http started on port 8080
    [2016-06-09 09:03:12] <web> {} [info] https started on port 8443

If there is a problem loading the `https` entry from the keystore,
you will see an error message similar to this. Make sure you have loaded the
private key and certificate chain with alias `https`.

    [2016-06-09 09:05:20] <http> {} [err] Failed to obtain entry with alias 'https' from the keystore. Disabling HTTPS
    [2016-06-09 09:05:20] <web> {} [info] http started on port 8080

NOTE: when running https, all http traffic is redirected to https.

In SkySpark you can upload your private key and certificate through the UI using this
procedure:

  1. Go to the `Host` app
  1. Select the `Crypto` view
  1. Click the `Add Cert` button
  1. In the dialog specify the alias for the key/cert bundle (e.g. `https`)
  1. Then paste in the PEM encoding of your private key and certificate chain

# Trusted Certificates
Haxall maintains its own trust store for trusted certificates. By default,
the trust store includes every trusted certificate in the Java environment. If
you are getting this exception when trying to connect via SSL/TLS to a remote host:

```
  sys::IOErr: javax.net.ssl.SSLHandshakeException: sun.security.validator.ValidatorException:
  PKIX path building failed: sun.security.provider.certpath.SunCertPathBuilderException: unable to find valid certification path to requested target
```

then it means that one or more certificates in the certificate chain is not
signed by a trusted authority. To trust all the certificates for any SSL/TLS
endpoint (e.g. HTTP, SMTP, etc.) use the `crypto` tool:

```
// Get help on adding entries to the trust store
hx crypto trust -help

// Usage 1: Trust all certificates in the certificate chain for the given URI.
hx crypto trust -uri https://example.com

// Usage 2: Add all certificates in the given PEM file to the trust store
hx crypto trust -cert certToTrust.pem
```

Note: Haxall must be stopped before using the `crypto` tool.

In SkySpark, you can also use the following procedure:

  1. Go to the `Host` app
  1. Select the `Crypto` view
  1. Click the `Trust Uri` action button
  1. In the dialog enter the uri of the SSl/TLS endpoint for which you want
     to trust all the certificates. The alias is optional.
  1. Click Ok.

If that procedure fails, you can attempt to trust the URI from the command line
using the `crypto` tool as explained above. Using this tool may give you more
insight into why it is failing.