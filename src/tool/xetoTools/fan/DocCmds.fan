//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Apr 2023  Brian Frank  Creation
//

using util
using xeto
using haystack
using xetom
using xetodoc


**
** Base class for doc commands
**
internal abstract class AbstractDocCmd : SrcLibCmd
{
  @Opt { help = "Output directory" }
  File? outDir

  override Int process(XetoEnv env, LibVersion[] vers)
  {
    // flatten and build namespace
    depends := vers.map |x->LibDepend| { x.asDepend }
    flatten := env.repo.solveDepends(depends)
    ns := env.createNamespace(flatten)

    // get libs to compile
    libs := vers.map |v->Lib| { ns.lib(v.name) }

    // output directory
    outDir := this.outDir ?: Env.cur.workDir + `${name}/`

    // compile
    c := DocCompiler
    {
      it.ns     = ns
      it.libs   = libs
      it.outDir = outDir
    }
    compile(c)
    return 0
  }

  abstract Void compile(DocCompiler c)
}

**************************************************************************
** DocHtmlCmd
**************************************************************************

internal class DocHtmlCmd : AbstractDocCmd
{
  override Str name() { "doc-html" }

  override Str summary() { "Compile documentation to HTML files" }

  override Void compile(DocCompiler c) { c.compileHtml }
}

**************************************************************************
** DocJsonCmd
**************************************************************************

internal class DocJsonCmd : AbstractDocCmd
{
  override Str name() { "doc-json" }

  override Str summary() { "Compile documentation to JSON AST files" }

  override Void compile(DocCompiler c) { c.compileJson }
}

