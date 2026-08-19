//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Aug 2026  Brian Frank  Creation
//

using util
using xeto
using xetom
using haystack

**
** Scanner is abstracts scanning LibFiles across xetolib
** zip files, source directories, and single file compiles.
**
@Js
internal abstract class Scanner
{
  ** Create for the given input.  The companion has no input file at all -
  ** its source comes from the project records - so it dispatches on the
  ** compile rather than on the file.
  static Scanner create(ParseStep step)
  {
    if (step.compiler.isCompanion && step.mode.isLib) return CompanionScanner(step)

    input := step.input
    if (input.ext == "xetolib") return ZipScanner(step, input)
    if (input.isDir) return DirScanner(step, input)
    return FileScanner(step, input)
  }

  ** Constructor
  new make(ParseStep step) { this.step = step }

  ** Is this a xetolib zip file scanner
  virtual Bool isZip() { false }

  ** Read the build vars to be used.  Zip files package
  ** their own vars in "/xeto-build.props".
  virtual BuildVars readBuildVars(BuildVars src) { src }

  ** Precompiled lib meta packaged in a xetolib zip, else null when the
  ** input is source and there is nothing to cross check against
  virtual [Str:Str]? readMetaProps() { null }

  ** Get libMeta or return null/non-nonexistent file if missing
  abstract File? libMeta()

  ** Iterate the source files excluding "lib.xeto" which is already parsed
  virtual Void eachSrcFile(LibFiles files, |LibFile| cb)
  {
    files.published.each |f|
    {
      if (f.uri.ext != "xeto") return
      if (f.uri == `/lib.xeto`) return
      cb(f)
    }
  }

  ** Perform scan - must have called scanPrep
  MLibFiles scan(APragma pragma)
  {
    this.include = pragma.include.reset
    this.publish = pragma.publish.reset

    acc := Uri:LibFile[:]
    doScan |uri, f| { scanFile(acc, uri, f) }

    this.include.check(this)
    this.publish.check(this)

    return MLibFiles(acc)
  }

  private Void scanFile(Uri:LibFile acc, Uri uri, File f)
  {
    // always skip hidden files
    if (XetoUtil.isHiddenFile(uri.name)) return

    // no file can start with "xeto-"
    if (XetoUtil.isXetoSystemFile(uri.name))
    {
      // ignore system files in xetolib
      if (isZip) return

      // report error
      err("Invalid file name '$uri.name': File name cannot use reserved prefix '$XetoUtil.xetoSystemFilePrefix'", FileLoc(f))
      return
    }

    // sources and chapters are intrinsically published or in 'publish' patterns
    isPublished := XetoUtil.isPublishIntrinsic(uri) || publish.matches(uri)

    // includes is anything published or in 'include' patterns
    isIncluded := isPublished || include.matches(uri)
    if (!isIncluded) return

    // if published verify its a valid publish file name
    if (isPublished) checkPublishPath(uri, f)

    // we have a valid publish file
    scanAdd(acc, reify(uri, f, isPublished))
  }

  private Void scanAdd(Uri:LibFile acc, LibFile f)
  {
    if (XetoUtil.isJavaScript(f.uri)) hasJavaScript = true
    if (XetoUtil.isChapter(f.uri))    hasChapters = true
    if (XetoUtil.isCss(f.uri))        hasCss = true
    acc.add(f.uri, f)
  }

  ** Lib flags to apply after scan is complete
  Int scanLibFlags()
  {
    flags := 0
    if (hasJavaScript) flags = flags.or(MLibFlags.hasJavaScript)
    if (hasChapters)   flags = flags.or(MLibFlags.hasChapters)
    if (hasCss)        flags = flags.or(MLibFlags.hasCss)
    return flags
  }

  private Bool hasJavaScript // if any js/*.js detected
  private Bool hasChapters // any chapter resources detected
  private Bool hasCss // if any css/*.css detected

  ** Report the first invalid section of a published path.  A directory is
  ** walked once per file beneath it, so report each bad name only once.
  private Void checkPublishPath(Uri uri, File f)
  {
    // check file name itself
    e := XetoUtil.publishFileNameErr(uri.name)
    if (e != null) return err("Invalid file name '$uri.name': $e", FileLoc(f))

    // check directory path names (report once)
    uri.path[0..-2].eachWhile |n, i|
    {
      e = XetoUtil.publishFileNameErr(n)
      if (e == null) return null

      badPath := "/" + uri.path[0..i].join("/") + "/"
      if (badPaths[badPath] == null)
      {
        badPaths[badPath] = badPath
        err("Invalid file path name '$n': $e", FileLoc(f))
      }
      return "break"
    }
  }
  ** Scan every file using the normalized lib URI "/foo.ext"
  protected abstract Void doScan(|Uri,File| cb)

  ** Turn scan uri + file into the proper LibFile instance
  protected abstract LibFile reify(Uri uri, File file, Bool isPublished)

  ** Close the scanner if holding resources
  virtual Void close() {}

  ** Invoke the onErr callback
  Void err(Str msg, FileLoc loc)
  {
    step.err(msg, loc)
  }

  protected ParseStep step
  private ScannerPatternList? include
  private ScannerPatternList? publish
  private Str:Str badPaths := [:]
}

**************************************************************************
** ScannerPattern
**************************************************************************

@Js
internal class ScannerPatternList
{
  new make(Str name, LibFilePattern[] patterns, FileLoc loc)
  {
    this.name = name
    this.patterns = patterns
    this.loc = loc
  }

  ** Must call resest for scanning - just to make sure re-entry
  This reset()
  {
    this.hits = Bool[,].fill(false, patterns.size); return this
  }

  ** Stop at the first hit: a pattern only counts as matched when it is
  ** the one which actually selected the file.  A second pattern matching
  ** the same file is a duplicate, and a pattern naming a file already
  ** selected intrinsically is redundant - both are author mistakes we
  ** want reported, not tolerated.
  Bool matches(Uri uri)
  {
    for (i := 0; i<patterns.size; ++i)
    {
      match := patterns[i].matches(uri)
      if (match) { hits[i] = true; return true }
    }
    return false
  }

  Void check(Scanner s)
  {
    patterns.each |p, i|
    {
      if (!hits[i])
       s.err("No matching files for $name pattern: $p", loc)
    }
  }

  const Str name
  const LibFilePattern[] patterns
  const FileLoc loc
  private Bool[]? hits
}

**************************************************************************
** ZipScanner
**************************************************************************

@Js
internal class ZipScanner : Scanner
{
  new make(ParseStep step, File zipFile) : super(step)
  {
    this.zipFile = zipFile
    this.zip = Zip.open(zipFile)
  }

  override Bool isZip() { true }

  override BuildVars readBuildVars(BuildVars src)
  {
    BuildVars.read(zip.contents[XetoUtil.xetoBuildPropsUri])
  }

  override File? libMeta()
  {
    zip.contents[`/lib.xeto`]
  }

  override [Str:Str]? readMetaProps()
  {
    zip.contents[XetoUtil.xetoMetaPropsUri]?.readProps
  }

  override Void doScan(|Uri,File| cb)
  {
    zip.contents.each |f,u| { cb(u,f) }
  }

  override LibFile reify(Uri uri, File file, Bool isPublished)
  {
    ZipLibFile(zipFile, uri, file, isPublished)
  }

  override Void close()
  {
    try { zip.close } catch {}
  }

  private File zipFile
  private Zip zip
}

**************************************************************************
** DirScanner
**************************************************************************

@Js
internal class DirScanner : Scanner
{
  new make(ParseStep step, File root) : super(step) { this.root = root }

  override File? libMeta() { root.plus(`lib.xeto`) }

  override Void doScan(|Uri,File| cb) { walk("", root, cb) }

  private static Void walk(Str path, File f, |Uri,File| cb)
  {
    if (f.isDir) f.list.each |sub| { walk(path+"/"+sub.name, sub, cb) }
    else cb(path.toUri, f)
  }

  override LibFile reify(Uri uri, File file, Bool isPublished)
  {
    LocalLibFile(uri, file, isPublished)
  }

  const File root
}

**************************************************************************
** FileScanner
**************************************************************************

@Js
internal class FileScanner : Scanner
{
  new make(ParseStep step, File file) : super(step)  { this.file = file }

  override File? libMeta() { file }

  override Void doScan(|Uri,File| cb) {}

  override LibFile reify(Uri uri, File file, Bool isPublished)
  {
    LocalLibFile(uri, file, isPublished)
  }

  const File file
}


**************************************************************************
** CompanionScanner
**************************************************************************

** The companion lib has no files: its source is synthesized from the
** project records.  It scans nothing and packages nothing, so the only
** thing it supplies is the source to parse - a stub pragma plus one unit
** per record.
@Js
internal class CompanionScanner : Scanner
{
  new make(ParseStep step) : super(step) {}

  ** Stub pragma source to parse like other normal APragma
  override File? libMeta()
  {
    Str<|pragma: Lib <
           version: "0.0.0"
         >
       |>.toBuf.toFile(`lib.xeto`)
  }

  ** Print each record back to Xeto source as its own compilation unit, so
  ** a parse error in one rec is attributed to that rec and quarantined
  ** independently.  Recs already marked in error are skipped, which is what
  ** lets partial compilation compile the still-ok subset (see
  ** CompanionCompiler).  Funcs are each wrapped in their own '+Funcs' block
  ** so they all merge into one mixin (see multi-file mixins).
  override Void eachSrcFile(LibFiles files, |LibFile| cb)
  {
    recs := step.ns.companionRecs ?: throw Err("No companion recs")
    recs.each |rec|
    {
      if (rec.status.isErr) return
      cb(MemStrLibFile(`/$rec.name`, printRec(rec), true, rec.loc))
    }
  }

  private Str printRec(CompanionRec rec)
  {
    s := StrBuf()
    if (rec.isFunc)
    {
      s.add("+Funcs {\n")
      XetoPrinter(step.ns, s.out, printOpts).ast(rec.rec)
      s.add("}\n")
    }
    else
    {
      XetoPrinter(step.ns, s.out, printOpts).ast(rec.rec)
    }
    return s.toStr
  }

  private once Dict printOpts()
  {
    Etc.dict2("noInferMeta", Marker.val, "qnameForce", Marker.val)
  }

  ** Return no files - we don't pin our temp source files in memory!
  override Void doScan(|Uri,File| cb) {}

  ** Cannot use
  override LibFile reify(Uri uri, File file, Bool isPublished) { throw UnsupportedErr() }
}

