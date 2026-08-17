//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Jul 2022  Brian Frank  Creation
//

using util
using xeto
using xetom
using haystack

**
** Base class for parsing steps
**
@Js
internal abstract class ParseStep : Step
{
  ** Convenience to parse file
  Void parseFile(File input, ADoc doc, BuildVars buildVars)
  {
    parse(FileLoc(input), input.readAllStr, doc, buildVars)
  }

  ** Choke point for parsing all compilation units
  Void parse(FileLoc loc, Str fileStr, ADoc doc, BuildVars buildVars)
  {
    try
    {
      Parser(this, loc, fileStr, doc, buildVars.vars).parse
    }
    catch (FileLocErr e)
    {
      err(e.msg, e.loc)
    }
    catch (Err e)
    {
      err(e.toStr, loc, e)
    }
  }
}

**************************************************************************
** ParseData
**************************************************************************

@Js
internal class ParseData : ParseStep
{
  override Void run()
  {
    // create ADataDoc for our root AST
    doc := ADataDoc(compiler, FileLoc(input))
    compiler.ast  = doc
    compiler.data = doc

    // parse input into doc
    parseFile(input, doc, BuildVars.empty)
    bombIfErr
  }
}

**************************************************************************
** ParseAst
**************************************************************************

@Js
internal class ParseLib : ParseStep
{
  override Void run()
  {
    // initialize the scanner
    scanner := Scanner.create(this)
    try
    {
      // run with the scanner
      doRun(scanner)
    }
    finally
    {
      // close scanner
      scanner.close
    }
  }

  private Void doRun(Scanner scanner)
  {
    // create ALib as our root AST
    lib := ALib(compiler, FileLoc(input), compiler.libName)
    compiler.ast = lib
    compiler.lib = lib

    // give xetolib zip scanner chance to use its own build vars
    buildVars := scanner.readBuildVars(compiler.srcBuildVars)

    // parse "lib.xeto" first - its pragma decides what the scan may package
    parseLibXeto(scanner, lib, buildVars)
    bombIfErr

    // everything the pragma declares is parsed and checked here
    APragma.extract(this, lib)
    bombIfErr

    // a xetolib carries precompiled meta which must agree with the source
    checkMetaProps(scanner, lib)
    bombIfErr

    // now that include/publish are known we can scan and classify the files
    lib.ast.files = scanFiles(scanner, lib)
    if (scanner.hasChapters) lib.ast.flags = lib.flags.or(MLibFlags.hasChapters)

    // parse remaining source files thru scanner
    parseSrcFiles(scanner, lib, buildVars)
    bombIfErr
  }

  ** Parse the lib.xeto file which declares the pragma
  private Void parseLibXeto(Scanner scanner, ALib lib, BuildVars buildVars)
  {
    libXeto := scanner.libMeta
    if (libXeto == null || !libXeto.exists) throw err("Missing 'lib.xeto'", FileLoc(input))
    parseFile(libXeto, lib, buildVars)
  }

  ** A xetolib packages "xeto-meta.props" so its name, version, and depends
  ** can be read without compiling it.  That makes it a second source of
  ** truth for facts which lib.xeto also declares, so a zip whose props
  ** disagree would resolve as one lib and compile as another.  Reject it.
  private Void checkMetaProps(Scanner scanner, ALib lib)
  {
    props := scanner.readMetaProps
    if (props == null) return

    pragma := lib.pragma
    checkMetaProp(props, "name", lib.name)
    checkMetaProp(props, "version", pragma.version.toStr)
    checkMetaProp(props, "depends", pragma.depends.join(";"))
  }

  private Void checkMetaProp(Str:Str props, Str name, Str expect)
  {
    actual := props[name]
    if (actual == null) return err("Missing '$name' in $XetoUtil.xetoMetaPropsUri", FileLoc(input))
    if (actual == expect) return
    err("Mismatched '$name' in $XetoUtil.xetoMetaPropsUri: $actual.toCode != $expect.toCode", FileLoc(input))
  }

  ** Scan source and resource files
  private MLibFiles scanFiles(Scanner scanner, ALib lib)
  {
    if (mode.isParseLibMeta) return MLibFiles.empty

    return scanner.scan(lib.pragma)
  }

  ** Parse every source file in the lib except lib.xeto which is already done
  private Void parseSrcFiles(Scanner scanner, ALib lib, BuildVars buildVars)
  {
    scanner.eachSrcFile(lib.files) |f|
    {
      parse(f.loc, f.readAllStr, lib, buildVars)
    }
  }

}

