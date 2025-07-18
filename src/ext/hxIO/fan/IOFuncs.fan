//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Nov 2010  Brian Frank  Creation
//

using web
using xeto
using haystack
using def
using hx
using folio
using axon
using hxUtil

**
** I/O library functions
**
const class IOFuncs
{

//////////////////////////////////////////////////////////////////////////
// Handles
//////////////////////////////////////////////////////////////////////////

  **
  ** Generate randomized series of bytes which can be used as an input I/O handle.
  **
  @Axon { admin = true }
  static Obj ioRandom(Number size)
  {
    Buf.random(size.toInt)
  }

  **
  ** Configure an I/O handle to use the specified charset.  The handle
  ** is any supported [I/O handle]`doc#handles` and the charset is a string
  ** name supported by the JVM installation.  Standard charset names:
  **   - "UTF-8" 8-bit Unicode Transformation Format
  **   - "UTF-16BE": 16 bit Big Endian Unicode Transformation Format
  **   - "UTF-16LE" 16 bit Little Endian Unicode Transformation Format
  **   - "ISO-8859-1": Latin-1 code block
  **   - "US-ASCII": 7-bit ASCII
  **
  ** Examples:
  **   // write text file in UTF-16BE
  **   ioWriteStr(str, ioCharset(`io/foo.txt`, "UTF-16BE"))
  **
  **   // read CSV file in ISO-8859-1
  **   ioCharset(`io/foo.csv`, "ISO-8859-1").ioReadCsv
  **
  @Axon { admin = true }
  static Obj? ioCharset(Obj? handle, Str charset)
  {
    CharsetHandle(toHandle(handle), Charset.fromStr(charset))
  }

  **
  ** Convert a handle to append mode.  Writes will append to the end
  ** of the file instead of rewriting the file.  Raises UnsupportedErr
  ** if the handle doesn't support append mode.
  **
  ** Example:
  **   ioWriteStr("append a line\n", ioAppend(`io/foo.txt`))
  **
  @Axon { admin = true }
  static Obj? ioAppend(Obj? handle)
  {
    toHandle(handle).toAppend
  }

//////////////////////////////////////////////////////////////////////////
// File Management
//////////////////////////////////////////////////////////////////////////

  **
  ** Read a directory listing, return a grid with cols:
  **   - 'uri': Uri for handle to read/write the file
  **   - 'name': filename string
  **   - 'mimeType': file mime type or null if unknown
  **   - 'dir':  marker if file is a sub-directory or null
  **   - 'size': size of file in bytes or null
  **   - 'mod':  modified timestamp or null if unknown
  **
  ** If the I/O handle does not map to a file in the virtual file system then
  ** throw an exception.
  **
  **   ioDir(`io/`)             // read files in project's io/ directory
  **   ioDir(`fan://haystack`)  // read files in pod
  **
  @Axon { admin = true }
  static Grid ioDir(Obj? handle)
  {
    h := toHandle(handle)
    return toInfoGrid(h.dir)
  }

  **
  ** Get information about a file handle and return a Dict with the
  ** same tags as `ioDir()`.
  **
  ** If the I/O handle does not map to a file in the virtual file system then
  ** throw an exception.
  **
  **   ioInfo(`io/`)            // read file info for the project's io/ directory
  **   ioInfo(`io/sites.trio`)  // read file info for the io/sites.trio file
  **
  @Axon { admin = true }
  static Dict ioInfo(Obj? handle)
  {
    h := toHandle(handle)
    return toInfoGrid([h.info]).first
  }

  ** Build a Grid for the given DirItems
  private static Grid toInfoGrid(DirItem[] items)
  {
    cols := ["uri", "name", "mimeType", "dir", "size", "mod"]
    colMeta := [null, null, null, null, Etc.makeDict(["format": "B"]), null]
    rows := [,]
    items.each |item|
    {
      mime := item.mime?.noParams?.toStr
      dir  := item.isDir ? Marker.val : null
      size := item.size != null ? Number.makeInt(item.size) : null
      rows.add([item.uri, item.name, mime, dir, size, item.mod])
    }
    return Etc.makeListsGrid(null, cols, colMeta, rows)
  }

  **
  ** Create a directory or empty file with the given I/O handle.
  ** If creating a file that already exists, it is overwritten as empty.
  **
  ** Examples:
  **   ioCreate(`io/new-dir/`)        // create new empty directory
  **   ioCreate(`io/new-file.txt`)    // create new empty file
  **
  @Axon { admin = true }
  static Obj? ioCreate(Obj? handle)
  {
    h := toHandle(handle)
    h.create
    return null
  }

  **
  ** Delete a file or a directory as mapped by the given I/O handle.
  ** If a directory is specified, then it is recursively deleted.  If the
  ** I/O handle does map to a file system then raise exception.  If the
  ** file does not exist then no action is taken.
  **
  @Axon { admin = true }
  static Obj? ioDelete(Obj? handle)
  {
    if (handle is List)
    {
      ((List)handle).each |h| { ioDelete(h) }
      return null
    }
    toHandle(handle).delete
    return null
  }

  **
  ** Copy a file or directory to the new specified location.
  ** If this file represents a directory, then it recursively
  ** copies the entire directory tree.  Both handles must reference
  ** a local file or directory on the file system.
  **
  ** If during the copy, an existing file of the same name is found,
  ** then the "overwrite" option should be to marker or 'true' to
  ** overwrite or 'false' to skip.  Or if overwrite is not defined
  ** then an IOErr is raised.
  **
  ** Examples:
  **   ioCopy(`io/dir/`, `io/dir-copy/`)
  **   ioCopy(`io/file.txt`, `io/file-copy.txt`)
  **   ioCopy(`io/file.txt`, `io/file-copy.txt`, {overwrite})
  **   ioCopy(`io/file.txt`, `io/file-copy.txt`, {overwrite:false})
  **
  @Axon { admin = true }
  static Obj? ioCopy(Obj? from, Obj? to, Dict opts := Etc.emptyDict)
  {
    fromFile := toHandle(from).toFile("ioCopy")
    toFile   := toHandle(to).toFile("ioCopy")
    optsFile := opts.has("overwrite") ? ["overwrite": !(opts["overwrite"] == false)] : [:]
    fromFile.copyTo(toFile, optsFile)
    return null
  }

  **
  ** Move or rename a file or directory.  Both handles must reference
  ** a local file or directory on the file system.  If the target file
  ** already exists then raise an IOErr.
  **
  @Axon { admin = true }
  static Obj? ioMove(Obj? from, Obj? to)
  {
    fromFile := toHandle(from).toFile("ioMove")
    toFile   := toHandle(to).toFile("ioMove")
    fromFile.moveTo(toFile)
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Str
//////////////////////////////////////////////////////////////////////////

  **
  ** Read an I/O handle into memory as a string.
  ** Newlines are always normalized into "\n" characters.
  **
  @Axon { admin = true }
  static Str ioReadStr(Obj? handle)
  {
    toHandle(handle).withIn |in| { in.readAllStr }
  }

  **
  ** Write a string to an I/O handle.
  **
  @Axon { admin = true }
  static Obj? ioWriteStr(Str str, Obj? handle)
  {
    toHandle(handle).withOut |out| { out.print(str) }
  }

//////////////////////////////////////////////////////////////////////////
// Lines
//////////////////////////////////////////////////////////////////////////

  **
  ** Read an I/O handle into memory as a list of string lines.
  ** Lines are processed according to `sys::InStream.readLine` semanatics.
  **
  ** By default the maximum line size read is 4kb of Unicode
  ** characters (not bytes).  This limit may be overridden using
  ** the option key "limit".
  **
  ** Examples:
  **   ioReadLines(`io/file.txt`)
  **   ioReadLines(`io/file.txt`, {limit: 10_000})
  **
  @Axon { admin = true }
  static Str[] ioReadLines(Obj? handle, Dict? opts := null)
  {
    io := toHandle(handle)

    // handle special case of max
    if (opts != null && opts.has("limit"))
    {
      return io.withIn |in|
      {
        max := ((Number)opts["limit"]).toInt
        acc := Str[,]
        while (true)
        {
          line := in.readLine(max)
          if (line == null) break
          acc.add(line)
        }
        return acc
      }
    }

    return io.withIn |in| { in.readAllLines }
  }

  ** For each line of the given source stream call the given function
  ** with two parameters: Str line and zero based Number line number.
  ** Lines are processed according to `sys::InStream.eachLine`.
  @Axon { admin = true }
  static Obj? ioEachLine(Obj? handle, Fn fn)
  {
    return toHandle(handle).withIn |in|
    {
      cx := curContext
      num := 0
      args := [null, null]
      in.eachLine |line|
      {
        fn.call(cx, args.set(0, line).set(1, Number(num)))
        num++
      }
      return Number(num)
    }
  }

  ** Read a stream of lines.  Lines are processed according to
  ** `sys::InStream.eachLine`.  See `docHaxall::Streams#ioStreamLines`.
  @Axon { admin = true }
  static Obj ioStreamLines(Obj? handle)
  {
    IOStreamLinesStream(toHandle(handle))
  }

  **
  ** Write a list of string lines separated with "\n" character.
  **
  @Axon { admin = true }
  static Obj? ioWriteLines(Str[] lines, Obj? handle)
  {
    toHandle(handle).withOut |out|
    {
      lines.each |line| { out.printLine(line) }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Trio
//////////////////////////////////////////////////////////////////////////

  **
  ** Read a [Trio]`docHaystack::Trio` file into memory as a list of Dicts.
  **
  @Axon { admin = true }
  static Dict[] ioReadTrio(Obj? handle)
  {
    toHandle(handle).withIn |in|
    {
      TrioReader(in).readAllDicts
    }
  }

  **
  ** Write dicts to a [Trio]`docHaystack::Trio` file.
  ** The 'val' may be can be any format accepted by `toRecList`.
  **
  ** Following options are supported
  **   - noSort: marker to prevent tags from being sorted by name
  **
  @Axon { admin = true }
  static Obj? ioWriteTrio(Obj? val, Obj? handle, Dict? opts := null)
  {
    dicts := Etc.toRecs(val)
    return toHandle(handle).withOut |out|
    {
      TrioWriter(out, opts).writeAllDicts(dicts)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Zinc
//////////////////////////////////////////////////////////////////////////

  **
  ** Read a [Zinc]`docHaystack::Zinc` file into memory as a Haystack data type.
  **
  @Axon { admin = true }
  static Grid ioReadZinc(Obj? handle)
  {
    toHandle(handle).withIn |in|
    {
      ZincReader(in).readGrid
    }
  }

  **
  ** Write a Grid to the [Zinc]`docHaystack::Zinc` format.
  **
  @Axon { admin = true }
  static Obj? ioWriteZinc(Obj? val, Obj? handle)
  {
    grid := toDataGrid(val)
    return toHandle(handle).withOut |out|
    {
      ZincWriter(out).writeGrid(grid)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Xeto
//////////////////////////////////////////////////////////////////////////

  **
  ** Read a Xeto data file into memory as a Haystack data type.
  ** See `xeto::LibNamespace.compileData` for details and options.
  **
  @Axon { admin = true }
  static Obj? ioReadXeto(Obj? handle, Obj? opts := null)
  {
    toHandle(handle).withIn |in|
    {
      Context.cur.ns.compileData(in.readAllStr, opts)
    }
  }

  **
  ** Write value to a Xeto text format file.
  ** See `xeto::LibNamespace.writeData` for details and options.
  **
  @Axon { admin = true }
  static Obj? ioWriteXeto(Obj? val, Obj? handle, Obj? opts := null)
  {
    return toHandle(handle).withOut |out|
    {
      Context.cur.ns.writeData(out, val, opts)
    }
  }

//////////////////////////////////////////////////////////////////////////
// CSV
//////////////////////////////////////////////////////////////////////////

  **
  ** Read a CSV (comma separated values) file into memory as a Grid.
  ** CSV format is implemented as specified by RFC 4180:
  **   - rows are delimited by a newline
  **   - cells are separated by 'delimiter' char
  **   - cells containing the delimiter, '"' double quote, or
  **     newline are quoted; quotes are escaped as '""'
  **   - empty cells are normalized into null
  **
  ** The following options are supported:
  **   - delimiter: separator char as string, default is ","
  **   - noHeader: if present then don't treat first row as col names,
  **     instead use "v0", "v1", etc
  **
  ** Also see `ioStreamCsv`, `ioEachCsv`, `ioWriteCsv`, and `docHaystack::Csv`.
  **
  @Axon { admin = true }
  static Grid ioReadCsv(Obj? handle, Dict? opts := null)
  {
    IOCsvReader(curContext, handle, opts).read
  }

  **
  ** Read a stream of dicts from a comma separated value file.  This
  ** function uses the same options and semantics as `ioReadCsv` except
  ** it streams the rows as dicts instead of reading to an in-memory grid.
  ** See `docHaxall::Streams#ioStreamCsv`.
  **
  @Axon { admin = true }
  static Obj? ioStreamCsv(Obj? handle, Dict? opts := null)
  {
    IOStreamCsvStream(handle, opts)
  }

  **
  ** Iterate the rows of a CSV file (comma separated values) and callback
  ** the given function with two parameters: Str[] cells of current row
  ** and zero based Number line number.
  **
  ** The following options are supported:
  **   - delimiter: separator char as string, default is ","
  **
  ** Also `ioReadCsv`, `ioWriteCsv`, and `docHaystack::Csv`.
  **
  @Axon { admin = true }
  static Obj? ioEachCsv(Obj? handle, Dict? opts, Fn fn)
  {
    IOCsvReader(curContext, handle, opts).each(fn)
  }

  **
  ** Write a grid to a [CSV]`docHaystack::Csv` (comma separated values) file.
  **
  ** CSV format is implemented as specified by RFC 4180:
  **   - rows are delimited by a newline
  **   - cells are separated by 'delimiter' char
  **   - cells containing the delimiter, '"' double quote, or
  **     newline are quoted; quotes are escaped as '""'
  **
  ** The following options are supported:
  **   - delimiter: separator char as string, default is ","
  **   - newline: newline string, default is "\n" (use "\r\n" for CRLF)
  **   - noHeader: Set this option to prevent the column names from being
  **     written as a header row.
  **   - stripUnits: write all numbers without a unit
  **
  ** Also `ioReadCsv`, `ioEachCsv`, and `docHaystack::Csv`.
  **
  @Axon { admin = true }
  static Obj? ioWriteCsv(Obj? val, Obj? handle, Dict? opts := null)
  {
    // parse options
    if (opts == null) opts = Etc.emptyDict
    delimiter  := opts["delimiter"] as Str ?: ","
    newline    := opts["newline"] as Str ?: "\n"
    header     := opts["noHeader"] == null
    stripUnits := opts["stripUnits"] != null

    grid := toDataGrid(val)
    return toHandle(handle).withOut |out|
    {
      csv := CsvWriter(out) { it.delimiter = delimiter[0]; it.newline = newline; it.showHeader = header; it.stripUnits = stripUnits }
      csv.writeGrid(grid).close
    }
  }

//////////////////////////////////////////////////////////////////////////
// Excel
//////////////////////////////////////////////////////////////////////////

  **
  ** Write an Excel XLS file, where 'val' may be:
  **   - Grid - writted a a single worksheet
  **   - Grid[] - each grid is exported as a separate worksheet
  **
  ** By default each worksheet is named "Sheet1", "Sheet2", etc.  Use
  ** a 'title' tag in Grid.meta to give the worksheets a specific name.
  **
  ** Example:
  **   readAll(site).ioWriteExcel(`io/sites.xls`)
  **
  @Axon { admin = true }
  static Obj? ioWriteExcel(Obj? val, Obj? handle)
  {
    // if Grid[], then write each grid as a worksheet
    listOfGrids := val is List && ((List)val).all |item| { item is Grid }
    if (listOfGrids)
    {
      return toHandle(handle).withOut |out|
      {
        ExcelWriter(out).writeWorkbook(val).close
      }
    }

    // single worksheet
    grid := toDataGrid(val)
    return toHandle(handle).withOut |out|
    {
      ExcelWriter(out).writeGrid(grid).close
    }
  }

//////////////////////////////////////////////////////////////////////////
// JSON
//////////////////////////////////////////////////////////////////////////

  **
  ** Read a JSON file into memory. This function can used to read any
  ** arbitrary JSON nested object/array structure which can be accessed
  ** as Axon dicts/lists.  The default decoding assumes Haystack 4 JSON
  ** format (Hayson).  Also see `ioReadJsonGrid` if reading a Haystack
  ** formatted grid.
  **
  ** Object keys which are not valid tag names will decode correctly
  ** and can be used in-process.  But they will not serialize correctly
  ** over the HTTP API.  You can use the 'safeNames' option to force object
  ** keys to be safe tag names (but you will lose the original key names).
  **
  ** The following options are supported:
  **   - v3: decode the JSON as Haystack 3
  **   - v4: explicitly request Haystack 4 decoding (default)
  **   - safeNames: convert object keys to safe tag names
  **
  @Axon { admin = true }
  static Obj? ioReadJson(Obj? handle, Dict? opts := null)
  {
    toHandle(handle).withIn |in|
    {
      return JsonReader(in, toJsonOpts(opts)).readVal
    }
  }

  private static Dict toJsonOpts(Dict? arg)
  {
    cx := curContext
    if (arg == null) arg = Etc.emptyDict
    if (cx.sys.platform.rt.isAxonsh) return Etc.emptyDict
    filetype := cx.defs.filetype("json")
    settings := cx.rt.ext("hx.io").rec
    return filetype.ioOpts(cx.defs, null, arg, settings)
  }

  **
  ** Read a JSON file formatted as a standardized Haystack grid
  ** into memory. See `ioReadJson` to read arbitrary JSON structured data.
  **
  @Axon { admin = true }
  static Grid ioReadJsonGrid(Obj? handle, Dict? opts := null)
  {
    toHandle(handle).withIn |in|
    {
      JsonReader(in, toJsonOpts(opts)).readGrid
    }
  }

  **
  ** Write an Axon data structure to JSON. By default,
  ** Haystack 4 (Hayson) encoding is used. The 'val' may be:
  **   - One of the SkySpark types that can be mapped to JSON.
  **     See `docHaystack::Json` for type mapping.
  **
  ** The following options are supported:
  **   - noEscapeUnicode: do not escape characters over 0x7F
  **   - v3: Encode JSON using Haystack 3 encoding
  **   - v4: Explicitly encode with Haystack 4 encoding (default)
  **
  @Axon { admin = true }
  static Obj? ioWriteJson(Obj? val, Obj? handle, Dict? opts := null)
  {
    toHandle(handle).withOut |out|
    {
      opts = toJsonOpts(opts)
      json := JsonWriter(out, toJsonOpts(opts))
      if (opts.has("noEscapeUnicode")) json.out.escapeUnicode = false
      json.writeVal(val)
    }
  }

//////////////////////////////////////////////////////////////////////////
// HTML
//////////////////////////////////////////////////////////////////////////

  ** Write an Axon data structure to HTML. The 'val' must be an
  ** Axon type that can be converted to a Grid.
  @Axon { admin = true }
  static Obj? ioWriteHtml(Obj? val, Obj? handle, Dict opts := Etc.emptyDict)
  {
    toHandle(handle).withOut |out|
    {
      req := Etc.dictMerge(opts, ["data": Etc.toGrid(val).toConst, "filetype":"html"])
      curContext.export(req, out)
    }
  }

//////////////////////////////////////////////////////////////////////////
// XML
//////////////////////////////////////////////////////////////////////////

  **
  ** Write a grid to an [XML]`docHaxall::Xml` file.
  **
  @Axon { admin = true }
  static Obj? ioWriteXml(Obj? val, Obj? handle)
  {
    grid := toDataGrid(val)
    return toHandle(handle).withOut |out|
    {
      XmlWriter(out).writeGrid(grid).close
    }
  }

//////////////////////////////////////////////////////////////////////////
// RDF
//////////////////////////////////////////////////////////////////////////

  ** Write an Axon data structure to RDF [Turtle]`docHaystack::Rdf` format.
  ** The 'val' must be an Axon type that can be converted to a Grid.
  @Axon { admin = true }
  static Obj? ioWriteTurtle(Obj? val, Obj? handle)
  {
    grid := toDataGrid(val)
    return toHandle(handle).withOut |out|
    {
      TurtleWriter(out, Etc.dict1("ns", curContext.defs)).writeGrid(grid)
    }
  }

  ** Write an Axon data structure to RDF [JSON-LD]`docHaystack::Rdf` format.
  ** The 'val' must be an Axon type that can be converted to a Grid.
  @Axon { admin = true }
  static Obj? ioWriteJsonLd(Obj? val, Obj? handle)
  {
    grid := toDataGrid(val)
    return toHandle(handle).withOut |out|
    {
      JsonLdWriter(out, Etc.dict1("ns", curContext.defs)).writeGrid(grid)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Zip
//////////////////////////////////////////////////////////////////////////

  **
  ** Read a zip file's entry listing, return a grid with cols:
  **   - 'path': path of entry inside zip as Uri
  **   - 'size': size of file in bytes or null
  **   - 'mod':  modified timestamp or null if unknown
  **
  ** The handle must reference a zip file in the file system.
  ** Use `ioZipEntry` to perform a read operation on one of the
  ** entries in the zip file.
  **
  ** Example:
  **   ioZipDir(`io/batch.zip`)
  **
  @Axon { admin = true }
  static Grid ioZipDir(Obj? handle)
  {
    cx := curContext

    // map handle to file
    file := toHandle(handle).toFile("ioZipDir")

    // get zip file contents
    zip  := IOUtil.openZip(file)
    contents := zip.contents
    zip.close

    cols := ["path", "size", "mod"]
    colMeta := [null, Etc.makeDict(["format": "B"]), null]
    rows := [,]
    contents.each |f|
    {
      size := f.size != null ? Number.makeInt(f.size) : null
      rows.add([f.uri, size, f.modified])
    }
    return Etc.makeListsGrid(null, cols, colMeta, rows)
  }

  **
  ** Return a I/O handle which may be used to read from a zip
  ** entry within a zip file.  The 'handle' parameter must be
  ** an I/O handle which references a zip file in the file system.
  ** The 'path' parameter must be a Uri which identifies the
  ** path of the entry within the zip file.  See `ioZipDir` to
  ** read the listing of paths within a zip.
  **
  ** Example:
  **   // read CSV file from within a zip
  **   ioZipEntry(`io/batch.zip`, `/zone-temp.csv`).ioReadCsv
  **
  @Axon { admin = true }
  static Obj? ioZipEntry(Obj? handle, Uri path)
  {
    // check handle
    try
      handle?.toImmutable
    catch (NotImmutableErr e)
      throw ArgErr("Unsuppored handle for ioZipEntry: $handle.typeof")
    return Etc.makeDict(["zipEntry":Marker.val, "file": handle, "path":path])
  }

  **
  ** Wrap an I/O handle to GZIP compress/uncompress.
  **
  ** Example:
  **   // generate GZIP CSV file
  **   readAll(site).ioWriteCsv(ioGzip(`io/sites.gz`))
  **
  **   // read GZIP CSV file
  **   ioGzip(`io/sites.gz`).ioReadCsv
  **
  @Axon { admin = true }
  static Obj? ioGzip(Obj? handle)
  {
    GZipEntryHandle(toHandle(handle))
  }

//////////////////////////////////////////////////////////////////////////
// Encoding/Decoding/Digests
//////////////////////////////////////////////////////////////////////////

  **
  ** Return an I/O handle to decode from a base64 string.
  ** Also see `ioToBase64()` and `sys::Buf.fromBase64`
  **
  ** Example:
  **   // decode base64 to a string
  **   ioFromBase64("c2t5c3Bhcms").ioReadStr
  **
  @Axon { admin = true }
  static Obj? ioFromBase64(Str s)
  {
    BufHandle(Buf.fromBase64(s))
  }

  **
  ** Encode an I/O handle into a base64 string.  The default behavior
  ** is to encode using RFC 2045 (see `sys::Buf.toBase64`).  Use the '{uri}'
  ** option to encode a URI-safe URI via RFC 4648 (see `sys::Buf.toBase64Uri`).
  ** Also see `ioFromBase64`.
  **
  ** Example:
  **   // encode string to base64
  **   ioToBase64("myusername:mysecret")
  **
  **   // encode string to base64 without padding using URI safe chars
  **   ioToBase64("myusername:mysecret", {uri})
  **
  @Axon { admin = true }
  static Str ioToBase64(Obj? handle, Dict? opts := null)
  {
    if (opts == null) opts = Etc.emptyDict
    buf := toHandle(handle).inToBuf
    return opts.has("uri") ? buf.toBase64Uri : buf.toBase64
  }

  **
  ** Encode an I/O handle into hexidecimal string.
  **
  @Axon { admin = true }
  static Str ioToHex(Obj? handle)
  {
    toHandle(handle).inToBuf.toHex
  }

  **
  ** Generate a cycle reduancy check code as a Number.
  ** See `sys::Buf.crc` for available algorithms.
  **
  ** Example:
  **   ioCrc("foo", "CRC-32").toHex
  **
  @Axon { admin = true }
  static Number ioCrc(Obj? handle, Str algorithm)
  {
    Number(toHandle(handle).inToBuf.crc(algorithm))
  }

  **
  ** Generate a one-way hash of the given I/O handle.
  ** See `sys::Buf.toDigest` for available algorithms.
  **
  ** Example:
  **   ioDigest("foo", "SHA-1").ioToBase64
  **
  @Axon { admin = true }
  static Obj? ioDigest(Obj? handle, Str algorithm)
  {
    toHandle(handle).inToBuf.toDigest(algorithm)
  }

  **
  ** Generate an HMAC message authentication as specified by RFC 2104.
  ** See `sys::Buf.hmac`.
  **
  ** Example:
  **   ioHmac("foo", "SHA-1", "secret").ioToBase64
  **
  @Axon { admin = true }
  static Obj? ioHmac(Obj? handle, Str algorithm, Obj? key)
  {
    toHandle(handle).inToBuf.hmac(algorithm, toHandle(key).inToBuf)
  }

  **
  ** Generate a password based cryptographic key. See `sys::Buf.pbk`.
  **
  ** Example:
  **   ioPbk("PBKDF2WithHmacSHA1", "secret", ioRandom(64), 1000, 20).ioToBase64
  **
  @Axon { admin = true }
  static Obj? ioPbk(Str algorithm, Str password, Obj? salt, Number iterations, Number keyLen)
  {
    Buf.pbk(
      algorithm,
      password,
      toHandle(salt).inToBuf,
      iterations.toInt,
      keyLen.toInt)
  }

  **
  ** Apply a skipping operation to an input I/O handle.  The
  ** following options are available (in order of processing):
  **   - bom: skip byte order mark
  **   - bytes: number of bytes to skip (must be binary input stream)
  **   - chars: number of chars to skip (must be text input stream)
  **   - lines: number of lines to skip
  **
  ** Skipping a BOM will automatically set the appropiate charset.
  ** If no BOM is detected, then this call is safely ignored by pushing
  ** those bytes back into the input stream.  The following byte
  ** order marks are supported:
  **   - UTF-16 Big Endian: 0xFE_FF
  **   - UTF-16 Little Endian: 0xFF_FE
  **   - UTF-8: 0xEF_BB_BF
  **
  ** Examples:
  **   // skip leading 4 lines in a CSV file
  **   ioSkip(`io/foo.csv`, {lines:4}).ioReadCsv
  **
  **   // skip byte order mark
  **   ioSkip(`io/foo.csv`, {bom}).ioReadCsv
  **
  @Axon { admin = true }
  static Obj? ioSkip(Obj? handle, Dict opts)
  {
    SkipHandle(toHandle(handle), opts)
  }

//////////////////////////////////////////////////////////////////////////
// SkySpark Exports
//////////////////////////////////////////////////////////////////////////

  **
  ** Render data to a PDF file.  The grid meta "view" tag determines
  ** the visualization:
  **   - 'table': render grid as [table]`docFresco::Tables` (default)
  **   - 'chart': render grid as [chart]`docFresco::Charts`
  **   - 'fandoc': render string as [fandoc]`fandoc::pod-doc#overview`
  **   - 'text': render as plaintext
  **
  ** Options:
  **   - `pageSize`: determines the PDF page size
  **
  ** Examples:
  **   // render as chart with default page size
  **   read(power).hisRead(yesterday).ioWritePdf(`io/portrait.pdf`)
  **
  **   // render as chart with landscape page size of 11" x 8.5"
  **   read(power).hisRead(yesterday).ioWritePdf(`io/landscape.pdf`, {pageSize:"11in,8.5in"})
  **
  **   // render table as single auto-fit page
  **   readAll(site).ioWritePdf(`io/sites.pdf`, {pageSize:"auto"})
  **
  ** Note: this feature is available in SkySpark only
  **
  @Axon { admin = true }
  static Obj? ioWritePdf(Obj? val, Obj? handle, Dict opts := Etc.emptyDict)
  {
    toHandle(handle).withOut |out|
    {
      try
      {
        req := Etc.dictMerge(opts, ["data":Etc.toGrid(val).toConst, "filetype":"pdf"])
        curContext.export(req, out)
      }
      catch (Err e)
      {
        e.trace
        throw e
      }
    }
  }

  **
  ** Render data to an SVG file.  Pass 'size' option to specify
  ** the SVG 'viewBox', 'width', and 'height' attribtues (defaults
  ** to "1000,800").  The visualization is determined by the grid meta
  ** "view" tag - see `ioWritePdf()` for specifics.
  **
  ** Examples:
  **   read(power).hisRead(yesterday).ioWriteSvg(`io/example.svg`)
  **
  **   read(power).hisRead(yesterday).ioWriteSvg(`io/example.svg`, {size:"600,400"})
  **
  ** Note: this feature is available in SkySpark only
  **
  @Axon { admin = true }
  static Obj? ioWriteSvg(Obj? val, Obj? handle, Dict opts := Etc.emptyDict)
  {
    toHandle(handle).withOut |out|
    {
      size := opts["size"] as Str ?: "1000,800"
      req := Etc.dictMerge(opts, ["data":Etc.toGrid(val).toConst, "filetype":"svg", "size":size])
      curContext.export(req, out)
    }
  }

  **
  ** Export a view to the given file handle - see `docFresco::Export`.
  **
  ** Note: this feature is available in SkySpark only
  **
  @Axon { admin = true }
  static Obj ioExport(Dict req, Obj? handle)
  {
    toHandle(handle).withOut |out|
    {
      curContext.export(req, out)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Coerce value to data grid
  internal static Grid toDataGrid(Obj? val)
  {
    Etc.toGrid(val)
  }

  ** Coerce to IOHandle
  internal static IOHandle toHandle(Obj? handle)
  {
    IOHandle.fromObj(curContext.rt, handle)
  }

  ** Current context
  internal static Context curContext()
  {
    Context.cur
  }
}

