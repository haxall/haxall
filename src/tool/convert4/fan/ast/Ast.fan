//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jul 2025  Brian Frank  Creation
//

using util
using haystack

**
** AST root
**
class Ast
{
  This scanWorkDir()
  {
    scan(Env.cur.workDir)
  }

  This scan(File f)
  {
    try
    {
      if (f.name == "build.fan") pods.addNotNull(APod.scan(this, f))
      if (f.isDir) f.list.each |sub| { scan(sub) }
    }
    catch (Err e)
    {
      Console.cur.err("Cannot scan dir [$f.osPath]", e)
    }
    return this
  }

  const File xetoSrcDir := Env.cur.workDir + `src/xeto/`

  AConfig config := AConfig.load

  APod[] pods := [,]

  AExt[] exts()
  {
    acc := AExt[,]
    pods.each |pod| { acc.addAll(pod.exts) }
    return acc
  }

//////////////////////////////////////////////////////////////////////////
// Tables
//////////////////////////////////////////////////////////////////////////

  Str[][] podsTable()
  {
    rows := Str[][,]
    rows.add(["name", "ext", "type", "dir", "fantomFuncs"])
    pods.each |pod|
    {
      pod.exts.each |ext|
      {
        rows.add([pod.name, ext.oldName, ext.type, pod.dir, pod.fantomFuncType])
      }
    }
    return rows
  }

  Str[][] extsTable()
  {
    rows := Str[][,]
    rows.add(["oldName", "libName", "type"])
    exts.each |ext|
    {
      rows.add([ext.oldName, ext.libName, ext.type.name])
    }
    return rows
  }

  Str[][] funcsTable()
  {
    rows := Str[][,]
    rows.add(["qname", "sig"])
    exts.each |ext|
    {
      ext.funcs.each |f|
      {
        qname := ext.oldName + "::" + f.name
        rows.add([qname, f.sig])
      }
    }
    return rows
  }

//////////////////////////////////////////////////////////////////////////
// Dumps
//////////////////////////////////////////////////////////////////////////

  Void dump(Console con := Console.cur)
  {
    dumpPods(con)
    dumpExts(con)
    dumpFuncs(con)
  }

  Void dumpPods(Console con := Console.cur)
  {
    con.info("")
    con.info("### Pods [$pods.size] ###")
    con.table(podsTable)
  }

  Void dumpExts(Console con := Console.cur)
  {
    con.info("")
    con.info("### Exts [$exts.size] ###")
    con.table(extsTable)
  }

  Void dumpFuncs(Console con := Console.cur)
  {
    con.info("")
    con.info("### Funcs ###")
    con.table(funcsTable)
  }

}

