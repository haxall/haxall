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
    ast = Ast().scanWorkDir
    ast.exts.each |ext|
    {
      // determe if we should run
      n := ext.oldName
      run := exts.contains(ext.oldName)
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
    switch (name)
    {
      case "doc":     return ext.meta["doc"] ?: "todo"
      case "depends": return resolveDepends(ext)
      default:        return null
    }
  }

  private Str resolveDepends(AExt ext)
  {
    s := StrBuf().add("{\n")
    addDepend(s, "sys")
    if (ext.libName != "hx") addDepend(s, "hx")
    s.add("  }")
    return s.toStr
  }

  private Void addDepend(StrBuf s, Str name)
  {
    prefix := name.split('.').first
    versions := ast.config.dependVersions[prefix]
    s.add("    { lib: $name.toCode")
    if (versions != null) s.add(", versions: $versions")
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
    genMeta(s, f.meta)
    s.add("{ ")
    f.eachSlot |p, comma|
    {
      if (comma) s.add(", ")
      genParam(s, p)
    }
    s.add(" }\n")
  }

  Void genParam(StrBuf s, AParam p)
  {
    s.add(p.name).add(": ").add(p.type.sig)
  }

  Void genMeta(StrBuf s, Dict meta)
  {
    if (meta.isEmpty) return
    s.add("<")
    keys := Etc.dictNames(meta)
    keys.moveTo("su", 0)
    keys.moveTo("admin", 0)
    keys.moveTo("nodoc", 0)
    keys.each |k, i|
    {
      if (i > 0) s.add(", ")
      s.add(k)
      v := meta[k]
      if (v == Marker.val) return
      s.add(":").add(v.toStr.toCode)
    }
    s.add("> ")
  }

  Void genDoc(StrBuf s, Str? doc)
  {
    doc = doc.trimToNull
    if (doc == null) return ""
    doc.eachLine |line| { s.add("// ").add(line).add("\n") }
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

