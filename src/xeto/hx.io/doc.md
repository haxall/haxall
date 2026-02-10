<!--
title:      IOExt
author:     Brian Frank
created:    11 Nov 10
copyright:  Copyright (c) 2010, SkyFoundry LLC
license:    Licensed under the Academic Free License version 3.0
-->

# Overview
The ioExt is used to read/write data via a variety of formats:
  - Text strings: [Funcs.ioReadStr], [Funcs.ioWriteStr]
  - Text lines: [Funcs.ioReadLines], [Funcs.ioWriteLines]
  - Zinc: [Funcs.ioReadZinc], [Funcs.ioWriteZinc]
  - Trio: [Funcs.ioReadTrio], [Funcs.ioWriteTrio]
  - CSV: [Funcs.ioReadCsv], [Funcs.ioWriteCsv], [Funcs.ioEachCsv], [Funcs.ioStreamCsv]
  - JSON: [Funcs.ioReadJson], [Funcs.ioWriteJson]
  - XML: [Funcs.ioWriteXml], [xmlRead()]
  - PDF: [Funcs.ioWritePdf]
  - SVG: [Funcs.ioWriteSvg]
  - HTML: [Funcs.ioWriteHtml]
  - RDF: [Funcs.ioWriteTurtle], [Funcs.ioWriteJsonLd]

# IO Handles
All the read/write functions take an *IO handle* which is one of
the following:

  - any string can be used by the the read functions; if used for a write
    function then the output is concatenated to the end of the string and
    returned as the result of the write function
  - Uri which starts with "io/" which read/writes relative to the
    project's io directory
  - Uri with `fan://` scheme will read files bundled in pods
  - Uri with `http://` or `https://` scheme will read using HTTP GET request (readonly)
  - Uri with `ftp://` or `ftps://` scheme will retreive using [FTP](hx.io::doc#ftp-handles)
  - any Dict can be used as an IOHandle. Data will be stored in Folio keyed off the
    'id' of the rec. The data will be removed when the rec is deleted from folio.

The default charset used by all I/O handles is "UTF-8".  You can wrap any of the
handles above with the [Funcs.ioCharset] function to specify an alternate charset.

## FTP Handles
You may read and write files to a FTP server via a `ftp://` or `ftps://` Uri.  Using [Funcs.ioDir]
is supported if Uri ends with a slash, but returns name only (not dir, size, or mod).
By default the "anonymous" user account is used.  But you can customize this by
creating a key/value the [password manager](hx.doc.haxall::Folio#passwords) where
the key is the base URI and the value is a string formatted as "user:pass".
For example given:

    uri:  ftp://somehost/somefile.csv
    user: bob
    pass: secret

You can setup the password for all FTP request to "ftp://somehost/" like this:

     passwordSet("ftp://somehost/", "bob:secret")

Note that the URI key must end with a slash and match the scheme (ftp or ftps).

In newer versions of Java, you may see the following warning in the console
the first time an FTPS connection is made:

```
WARNING: An illegal reflective access operation has occurred
WARNING: Illegal reflective access by fan.ftp.FtpClientPeer (file:) to field sun.security.ssl.SSLSessionContextImpl.sessionHostPortCache
WARNING: Please consider reporting this to the maintainers of fan.ftp.FtpClientPeer
WARNING: Use --illegal-access=warn to enable warnings of further illegal reflective access operations
WARNING: All illegal access operations will be denied in a future release
```

If you see this, then you need to edit your `etc/sys/config.props` and add the following
options to the `java.options` along with any other options you have set (e.g. heap configuration).

```
java.options=--add-opens java.base/sun.security.ssl=ALL-UNNAMED --add-opens java.base/sun.security.util=ALL-UNNAMED
```

# Examples
Here are some basic examples:

    // export your sites to a trio file: {proj}/io/sites.trio
    readAll(site).ioWriteTrio(`io/sites.trio`)

    // export your sites to a trio string literal
    readAll(site).ioWriteTrio("")

    // export point to CSV file
    read(weatherTemp).hisRead(pastMonth).ioWriteCsv(`io/point.csv`)

    // import history data from CSV file where timestamps
    // are formatted as 2010-10-02T13:00
    ioReadCsv(`io/his.csv`)
      .map(row => {ts: parseDateTime(row->ts, "YYYY-MM-DD'T'hh:mm", "New_York"),
                   val: parseNumber(row->val)})
      .hisWrite(hisId)

    // parse an oBIX XML document and map into name/value pairs
    xmlRead(`http://obix.acme.com/obix/about`).xmlElems
      .map(x => {name:x.xmlAttr("name").xmlVal, val:x.xmlAttr("val").xmlVal})

