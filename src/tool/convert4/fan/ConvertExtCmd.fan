//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jul 2025  Brian Frank  Creation
//

using util
using xeto
using haystack
using haystack::Macro
using hxm

internal class ConvertExtCmd : ConvertCmd
{
  override Str name() { "ext" }

  override Str summary() { "Convert hx::HxLib to Ext" }

  @Opt { help = "Generate lib.xeto" }
  Bool libXeto

  @Opt { help = "Generate funcs.xeto" }
  Bool funcs

  @Opt { help = "Generate everything" }
  Bool all

  @Opt { help = "Preview to console only" }
  Bool preview

  @Arg { help = "Specific old ext names or empty for all" }
  Str[] exts := [,]

  override Int run()
  {
    ast = Ast()
    scanFuncType := exts.size == 1 && exts.first.contains("::")
    if (scanFuncType)
    {
      // scan specific fantom qname for axon funcs
      ast.scanFuncsType(exts[0])
    }
    else
    {
      ast.scanWorkDir
    }

    ast.exts.each |ext|
    {
      // determe if we should run
      n := ext.oldName
      run := exts.contains(ext.oldName) || scanFuncType
      if (!run && exts.isEmpty)  run = !ast.config.ignore.contains(n)
      if (!run) return

      if (all || libXeto) genLibXeto(ext)
      if (all || funcs)   genFuncs(ext)
    }
    return 0
  }

//////////////////////////////////////////////////////////////////////////
// Gen lib.xeto
//////////////////////////////////////////////////////////////////////////

  Void genLibXeto(AExt ext)
  {
    // header
    header := genHeader()

    // body
    body := genMacro(ast.config.templateLibXeto) |name|
    {
      resolveLibXetoVar(ext, name)
    }

    // write out
    file := ext.xetoSrcDir + `lib.xeto`
    write("Lib xeto", file, header+"\n"+body)
  }

  private Str? resolveLibXetoVar(AExt ext, Str name)
  {
    doc := ext.meta["doc"] ?: "todo"
    switch (name)
    {
      case "doc":     return ext.meta["doc"] ?: "todo"
      case "depends": return resolveDepends(ext)
      case "libExt":  return ext.hasExt ? "libExt: $ext.specName" : ""
      case "extSpec": return ext.hasExt ? "// $doc\n" + ext.specName + ": " + ext.specBase : ""
      default:        return null
    }
  }

  private Str resolveDepends(AExt ext)
  {
    s := StrBuf().add("{\n")
    addDepend(s, "sys")
    if (!ext.funcs.isEmpty)  addDepend(s, "axon", "hx")
    if (ext.libName != "hx") addDepend(s, "hx")
    if (ext.dependOnIon) addDepend(s, "ion")
    s.add("  }")
    return s.toStr
  }

  private Void addDepend(StrBuf s, Str name, Str? prefix := null)
  {
    if (prefix == null) prefix = name.split('.').first
    versions := ast.config.dependVersions[prefix]
    nameCode := name.toCode.plus(",").padr(7)
    s.add("    { lib: $nameCode")
    s.add(" versions: $versions")
    s.add(" }\n")
  }

//////////////////////////////////////////////////////////////////////////
// Gen Funcs
//////////////////////////////////////////////////////////////////////////

  Void genFuncs(AExt ext)
  {
    if (ext.funcs.isEmpty) return

    s := StrBuf()
    s.add(genHeader)
    ext.funcs.each |f|
    {
      s.add("\n")
      genFunc(s, f)
    }

    file := ext.xetoSrcDir + `funcs.xeto`
    write("Funcs", file, s.toStr)
  }

  Void genFunc(StrBuf s, AFunc f)
  {
    genDoc(s, f.doc)
    s.add("$f.name: Func ")
    HxProjSpecs.encodeFuncMeta(s, f.meta)
    s.add("{ ")
    f.eachSlot |p, comma|
    {
      if (comma) s.add(", ")
      genParam(s, p)
    }
    if (f.axon != null)
    {
      heredoc := "---"
      while (f.axon.contains(heredoc)) heredoc += "-"
      s.add("\n")
      s.add("  <axon:").add(heredoc).add("\n")
      f.axon.splitLines.each |line| { s.add("  ").add(line).add("\n") }
      s.add("  ").add(heredoc).add(">\n").add("}\n")
    }
    else
    {
      s.add(" }\n")
    }
  }

  Void genParam(StrBuf s, AParam p)
  {
    s.add(p.name).add(": ").add(p.type.sig)
  }

  Void genDoc(StrBuf s, Str? doc)
  {
    doc = doc.trimToNull
    if (doc == null) return ""
    doc.eachLine |line|
    {
      s.add(("// " + line).trimEnd).add("\n")
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void write(Str msg, File file, Str src)
  {
    echo("-- $msg [$file.osPath]")
    if (preview)
    {
      echo(src)
    }
    else
    {
      file.out.print(src).close
    }
  }

  Str genHeader()
  {
    s := genMacro(ast.config.templateHeader) |n| { null }
    return s.trim + "\n"
  }

  Str genMacro(Str template, |Str->Str?| resolve)
  {
    macro := Macro(template)
    vars := Str:Str[:]
    macro.vars.each |name|
    {
      vars[name] = resolve(name) ?: resolveVarBuiltin(name)
    }
    return macro.apply |var| { vars[var] }
  }

  Str resolveVarBuiltin(Str var)
  {
    switch (var)
    {
      case "date":    return Date.today.toLocale("D MMM YYYY")
      case "year":    return Date.today.toLocale("YYYY")
    }
    throw Err("Unknown template var: $var")
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private Ast? ast
  private Console con := Console.cur
}

