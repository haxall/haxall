# Know Io

The io funcs read and write files, streams, and network resources.
Every io func takes a *handle* and most operations chain handle
transformers into read/write calls. All io funcs require admin.

# Handles

- `` `io/file.csv` ``: Uri into the project's io/ directory - the
  only writable file location; absolute paths and `..` escapes are
  rejected
- `"text"`: a Str is literal content, NOT a file path - forgetting
  the backticks silently reads your "filename" as content
- `` `https://host/path` ``: HTTP GET, read-only
- `` `ftp://host/file` ``: FTP read/write; credentials via
  `passwordSet("ftp://host/", "user:pass")`
- `` `fan://pod/file` ``: pod resource, read-only
- a rec dict: file content stored in folio, deleted with the rec
- `ioRandom(32)`: cryptographic random bytes

Handle transformers wrap another handle:

```axon
ioCharset(`io/f.txt`, "UTF-16BE")     // non-UTF-8 encoding
ioAppend(`io/log.txt`)                // append instead of replace
ioSkip(`io/f.csv`, {bom, lines:2})    // skip BOM/lines/chars/bytes
ioGzip(`io/data.csv.gz`)              // transparent gzip
ioZipEntry(`io/batch.zip`, `/a.csv`)  // one entry inside a zip
```

# Text

```axon
ioReadStr(`io/file.txt`)              // whole file (newlines → \n)
ioWriteStr("hello", `io/file.txt`)
ioReadLines(`io/file.txt`)            // Str[]
ioWriteLines(lines, `io/file.txt`)
ioStreamLines(`io/big.txt`).limit(100).collect
ioEachLine(`io/f.txt`, (line, num) => process(line))
```

# CSV

```axon
ioReadCsv(`io/data.csv`)                    // grid
ioReadCsv(`io/data.csv`, {delimiter:"|"})
ioReadCsv(`io/data.csv`, {noHeader})        // cols named v0, v1...
ioStreamCsv(`io/big.csv`)                   // stream of dicts
ioEachCsv(`io/big.csv`, (cells, num) => ...)  // raw Str[] cells
grid.ioWriteCsv(`io/out.csv`, {stripUnits, newline:"\r\n"})
```

CSV rules to remember:
- **Every value reads as a Str** - no automatic coercion; parse
  explicitly (`row->area.parseNumber`)
- Empty cells read as null; markers do not round-trip
- Header names are normalized to camelCase tag names; duplicates
  become `name`, `name_1`; blanks become `blank`

Import pipeline:

```axon
ioReadCsv(`io/sites.csv`).map(row => diff(null, {
  dis: row->name,
  area: row->sqft.parseNumber.as(1ft²),
  site}, {add})).commit
```

# Zinc, Trio, and Xeto

Full type fidelity (units, refs, dates, markers) - prefer these
over CSV/JSON when both ends are haystack systems:

```axon
ioReadZinc(`io/data.zinc`)  /  grid.ioWriteZinc(`io/out.zinc`)
ioReadTrio(`io/recs.trio`)  /  recs.ioWriteTrio(`io/out.trio`, {noSort})
ioReadXeto(`io/data.xeto`)  /  val.ioWriteXeto(`io/out.xeto`)
```

# JSON

```axon
ioReadJson(`io/data.json`)             // Hayson (Haystack 4)
ioReadJson(handle, {v3})               // Haystack 3 decoding
ioReadJson(handle, {safeNames})        // "a.b" key → "a_b" (lossy!)
ioReadJsonGrid(handle)                 // haystack grid JSON
val.ioWriteJson(`io/out.json`)
val.ioWriteJson(handle, {noEscapeUnicode})
```

- Default decoding is Hayson: type-prefixed strings such as
  `"d:2026-07-03"` parse into typed values
- `ioWriteJson` strips null tags entirely
- `safeNames` renames illegal keys irreversibly - keep the raw
  JSON if you need original keys

# HTTP Requests

`ioHttp(uri, method, headers, body, fn)` streams the response into
a callback:

```axon
ioHttp(`https://api.acme.com/sites`, "GET", null, null,
  (code, headers, body) => ioReadJson(body))

ioHttp(`https://api.acme.com/data`, "POST",
  {"Content-Type":"application/json", "Authorization": @cred-id},
  payload.ioWriteJson(""),
  (code, headers, body) => code)
```

A Ref header value resolves from the password store, keeping
secrets out of code.

# File Management and Zip

```axon
ioDir(`io/`)                     // grid: uri, name, dir, size, mod
ioInfo(`io/file.csv`)            // one file's metadata
ioCreate(`io/newdir/`)           // dirs end with /
ioDelete(`io/old.csv`)           // recursive, no error if missing
ioCopy(`io/a.csv`, `io/b.csv`, {overwrite})
ioMove(`io/a.csv`, `io/b.csv`)
ioZipDir(`io/batch.zip`)         // list entries
ioZipDir(`io/batch.zip`).each(e => ioZipEntry(`io/batch.zip`, e->path).ioReadCsv)
```

# Encoding and Digests

```axon
ioToBase64("user:pass")               // encode ({uri} for URI-safe)
ioFromBase64(str).ioReadStr
ioToHex(handle)
ioCrc("foo", "CRC-32")
ioDigest(handle, "SHA-256").ioToBase64
ioHmac(content, "SHA-1", key).ioToBase64
ioPbk("PBKDF2WithHmacSHA1", pass, ioRandom(64), 10000, 20)
```

# Other Formats

- `grid.ioWriteExcel(`io/out.xls`)`: grid or list of grids (one
  worksheet each; name via grid meta `title`)
- `grid.ioWriteXml(handle)`; parse XML with the hx.xml lib:
  `xmlRead(handle)` then navigate with xmlElems/xmlElem/xmlAttr/xmlVal
- `grid.ioWriteHtml(handle)`: HTML table
- `ioWriteTurtle` / `ioWriteJsonLd`: RDF exports
- `ioWritePdf` / `ioWriteSvg` (SkySpark): render grid meta `view`
  ("table", "chart", "text", "fandoc") to document

# Style Notes

- Uri backticks vs Str quotes: `` ioReadStr(`io/f.txt`) `` reads a
  file; `ioReadStr("io/f.txt")` returns the string "io/f.txt"
- Stream (`ioStreamCsv`/`ioStreamLines`) instead of reading large
  files into memory
- Coerce CSV strings immediately after reading
- Use Zinc or Trio for haystack-to-haystack data exchange
- Put slow imports/exports in a task
