//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jul 2025  Brian Frank  Creation
//

using util
using xeto
using xetom
using haystack
using haystack::Macro
using hxm

internal class ConvertExtCmd : ConvertCmd
{
  override Str name() { "ext" }

  override Str summary() { "Convert hx::HxLib to Ext" }

  @Opt { help = "Generate lib.xeto" }
  Bool libXeto

  @Opt { help = "Generate types.xeto" }
  Bool types

  @Opt { help = "Generate funcs.xeto" }
  Bool funcs

  @Opt { help = "Convert pod.fandoc to doc.md" }
  Bool doc

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
      if (all || types)   genTypes(ext)
      if (all || funcs)   genFuncs(ext)
      if (all || doc)     genPodDoc(ext)
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
    if (ext.dependOnRule) addDepend(s, "hx.rule", "skyspark")
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
// Gen Types
//////////////////////////////////////////////////////////////////////////

  Void genTypes(AExt ext)
  {
    if (ext.types.isEmpty) return

    s := StrBuf()
    s.add(genHeader)
    s.add("\n")
    ext.types.each |t|
    {
      genType(s, t)
    }

    file := ext.xetoSrcDir + `types.xeto`
    write("Types", file, s.toStr)
  }

  Void genType(StrBuf s, ADefType x)
  {
    genDoc(s, x.doc, "")
    s.add("$x.name: $x.base {\n")
    keys := x.slots.keys
    if (x.base.toStr != "Enum") keys = keys.sort
    keys.each |n, i|
    {
      if (i > 0) s.add("\n")
      genSlot(s, x.slots[n])
    }
    s.add("}\n\n")
  }

  Void genSlot(StrBuf s, ADefSlot x)
  {
    genDoc(s, x.doc, "  ")
    s.add("  $x.name")
    if (x.type.toStr != "Marker") s.add(": ").add(x.type)
    if (!x.meta.isEmpty) { s.add(" "); encodeSpecMeta(s, x.meta) }
    s.add("\n")
  }

//////////////////////////////////////////////////////////////////////////
// Gen Funcs
//////////////////////////////////////////////////////////////////////////

  Void genFuncs(AExt ext)
  {
    if (ext.funcs.isEmpty) return

    s := StrBuf()
    s.add(genHeader)
    s.add("\n")
    s.add("+Funcs {\n")
    ext.funcs.each |f|
    {
      s.add("\n")
      genFunc(s, f)
    }
    s.add("\n}\n")

    file := ext.xetoSrcDir + `funcs.xeto`
    write("Funcs", file, s.toStr)
  }

  Void genFunc(StrBuf s, AFunc f)
  {
    genDoc(s, f.doc, "  ")
    s.add("  $f.name: Func ")
    encodeSpecMeta(s, f.meta)
    s.add("{ ")
    f.eachSlot |p, comma|
    {
      if (comma) s.add(", ")
      genParam(s, p)
    }
    if (f.axonBody != null)
    {
      heredoc := "---"
      while (f.axonBody.contains(heredoc)) heredoc += "-"
      s.add("\n")
      s.add("    <axon:").add(heredoc).add("\n")
      f.axonBody.splitLines.each |line|
      {
        if (!line.trim.isEmpty) s.add("    ").add(line)
        s.add("\n")
      }
      s.add("    ").add(heredoc).add(">\n").add("  }\n")
    }
    else
    {
      s.add(" }\n")
    }
  }

  Void encodeSpecMeta(StrBuf buf, Dict meta)
  {
    if (meta.isEmpty) return
    buf.add("<")
    encodeDictPairs(buf, meta)
    buf.add("> ")
  }

  Void encodeDictPairs(StrBuf buf, Dict dict)
  {
    first := true
    dict.each |v, n|
    {
      if (first) first = false; else buf.add(", ")
      buf.add(n)
      if (v === Marker.val) return
      buf.add(":")
      encodeVal(buf, v)
    }
  }

  Void encodeVal(StrBuf buf, Obj v)
  {
    if (v is Dict)
    {
      buf.add("{")
      encodeDictPairs(buf, v)
      buf.add("}")
    }
    else if (v is AType)
    {
      buf.add(v.toStr)
    }
    else
    {
      buf.add(v.toStr.toCode)
    }
  }

  Void genParam(StrBuf buf, AParam p)
  {
    buf.add(p.name).add(": ").add(p.type.sig)
    if (!p.meta.isEmpty)
    {
      buf.add(" <")
      encodeDictPairs(buf, p.meta)
      buf.add(">")
    }
  }

  Void genDoc(StrBuf s, Str? doc, Str indent)
  {
    doc = doc.trimToNull
    if (doc == null) return ""
    doc.eachLine |line|
    {
      s.add(indent).add(("// " + line).trimEnd).add("\n")
    }
  }

//////////////////////////////////////////////////////////////////////////
// Gen Funcs
//////////////////////////////////////////////////////////////////////////

  Void genPodDoc(AExt ext)
  {
    if (ext.pod.dir == null) return
    fandocFile := ext.pod.dir + `pod.fandoc`
    if (!fandocFile.exists) return

    base := ext.oldName + "::pod.fandoc"
    mdFile := ext.xetoSrcDir + `doc.md`

    src := FixFandoc.convertFandocFile(base, fandocFile, fixLinks)
    write("Doc.md", mdFile, src)
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

  private Str genHeader()
  {
    ast.config.genHeader
  }

  private Str genMacro(Str template, |Str->Str?| resolve)
  {
    ast.config.genMacro(template, resolve)
  }

  once FixLinks fixLinks() { FixLinks.load }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private Ast? ast
  private Console con := Console.cur
  private Namespace ns := XetoEnv.cur.createNamespaceFromNames(["sys"])
}

