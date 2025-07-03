//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jan 2023  Brian Frank  Creation
//

using web
using xeto
using xeto::Dict
using xeto::Lib
using haystack
using axon
using xetoEnv::Printer
using folio

**
** Axon shell specific functions
**
const class ShellFuncs
{
  ** Exit the shell.
  @Axon static Obj? quit()
  {
    cx.isDone = true
    return noEcho
  }

  ** Set the show error trace flag.
  @Axon static Obj? showTrace(Bool flag)
  {
    cx.showTrace = flag
    return noEcho
  }

  ** Print help summary or help on a specific command.
  ** Examples:
  **    help()        // print summary
  **    help(using)   // print help for the using function
  @Axon static Obj? help(Obj? func := null)
  {
    out := cx.printer
    comment := out.theme.comment

    if (func == null)
    {
      out.nl
      out.color(comment)
      out.w("?, help            Print this help summary").nl
      out.w("quit, exit, bye    Exit the shell").nl
      out.w("help(func)         Help on a specific function").nl
      out.w("helpAll()          Print summary of all functions").nl
      out.w("print(val)         Pretty print value").nl
      out.w("showTrace(flag)    Toggle the show err trace flag").nl
      out.w("scope()            Print variables in scope").nl
      out.w("using()            Print data libraries in use").nl
      out.w("using(qname)       Import given data library").nl
      out.w("load(file)         Load virtual database").nl
      out.w("read(filter)       Read rec as dict from virtual database").nl
      out.w("readAll(filter)    Read recs as grid from virtual database").nl
      out.colorEnd(comment)
      out.nl
      return noEcho
    }

    f := func as TopFn
    if (f == null)
    {
      out.warn("Not a top level function: $func [$func.typeof]")
      return noEcho
    }

    s := StrBuf()
    s.add(f.name).add("(")
    f.params.each |p, i|
    {
      if (i > 0) s.add(", ")
      s.add(p.name)
      if (p.def != null) s.add(":").add(p.def)
    }
    s.add(")")

    sig := s.toStr
    doc := funcDoc(f)

    out.nl
    out.color(comment)
    out.w(sig).nl
    if (doc != null) out.nl.w(doc).nl
    out.colorEnd(comment)
    out.nl
    return noEcho
  }

  ** Print help summary of every function
  @Axon static Obj? helpAll()
  {
    out := cx.printer
    comment := out.theme.comment

    names := cx.funcs.keys.sort
    nameMax := maxStr(names)

    out.nl
    out.color(comment)
    names.each |n|
    {
      f := cx.funcs[n]
      if (isNoDoc(f)) return
      d := docSummary(funcDoc(f) ?: "")
      out.w(n.padr(nameMax) + " " + d).nl
    }
    out.colorEnd(comment)
    out.nl
    return noEcho
  }

  ** Pretty print the given value.
  **
  ** Options:
  **   - spec: "qname" | "own" | "effective"
  **   - doc: include spec documentation comments
  **   - json: pretty print dict tree as JSON
  **   - text: output as plain text (not string literal)
  **   - escapeUnicode: escape string literals with non-ASCII chars
  **   - width: max width of output text
  @Axon static Obj? print(Obj? val := null, Dict? opts := null)
  {
    cx.print(val, opts)
    return noEcho
  }

  ** Print the variables in scope
  @Axon static Obj? scope()
  {
    out := cx.out
    vars := cx.varsInScope
    names := vars.keys.sort
    nameMax := maxStr(names)

    out.printLine
    vars.keys.sort.each |n|
    {
      out.printLine("$n:".padr(nameMax+1) + " " + vars[n])
    }
    out.printLine
    return noEcho
  }

  ** Import data library into scope.
  **
  ** Examples:
  **   using()                // list all libraries currently in scope
  **   using("phx.points")    // import given library into scope
  **   using("*")             // import every library installed
  @Axon static Obj? _using(Str? name := null)
  {
    out := cx.out

    if (name != null)
    {
      cx.rt.defs.addUsing(name, out)
      return noEcho
    }

    out.printLine
    cx.xeto.versions.sort.each |x| { out.printLine("$x.name [$x.version]") }
    out.printLine
    return noEcho
  }

  ** Get library by qname (does not add it to using)
  @Axon static Lib datalib(Str qname)
  {
    cx.xeto.lib(qname)
  }

  ** Backdoor hook to refresh ref dis
  @NoDoc @Axon static Obj? refreshDisAll()
  {
    cx.db.refreshDisAll
    return "refreshed"
  }

//////////////////////////////////////////////////////////////////////////
// Load
//////////////////////////////////////////////////////////////////////////

  **
  ** Load the in-memory database from an Uri.  The uri must be have http/https
  ** scheme or reference a file on the local file system (using forward slash).
  ** The filename must have one of the following file extensions: zinc, json,
  ** trio, or csv.  Each record should define an 'id' tag, or if missing then
  ** an id will assigned automatically.
  **
  ** Options:
  **   - shortIds: will swizzle all internal refs to short ids
  **
  ** Examples:
  **   // load from the a local file
  **   load(`folder/site.json`)
  **
  **   // load from the a local file and use short ids
  **   load(`folder/site.json`, {shortIds})
  **
  **   // load from a HTTP URI
  **   load(`https://project-haystack.org/example/download/bravo.zinc`)
  **
  @Axon static Obj? load(Uri uri, Dict? opts := null)
  {
    ShellLoader(cx, uri, opts ?: Etc.dict0).load
  }

  **
  ** Unload all the data from the in-memory database.
  ** This is essentially a commit to remove all recs.
  **
  @Axon static Obj? unloadAll()
  {
    recs := cx.db.readAllList(Filter.has("id"))
    diffs := recs.map |rec->Diff| { Diff(rec, null, Diff.remove) }
    cx.db.commitAll(diffs)
    return "Removed $recs.size recs"
  }

//////////////////////////////////////////////////////////////////////////
// Libs
//////////////////////////////////////////////////////////////////////////

  ** Backdoor hook to load Axon functions from a resource pod.
  ** No checking is done for dependencies.
  @NoDoc @Axon static Obj? loadFuncs(Str libName)
  {
    // find the pod
    pod := Pod.find(libName + "Ext", false)
    if (pod == null) pod = Pod.find("hx" + libName.capitalize, false)
    if (pod == null) throw Err("Cannot find pod for $libName.toCode")

    // walk all the lib.trio files
    acc := Str:TopFn[:]
    pod.files.each |file|
    {
      if (file.ext == "trio" && file.pathStr.startsWith("/lib/"))
        loadFuncsFromTrio(acc, file)
    }

    // merge into context top funcs
    cx.funcs.setAll(acc)

    return "Loaded $acc.size funcs from $pod"
  }

  private static Void loadFuncsFromTrio(Str:TopFn acc, File file)
  {
    TrioReader(file.in).eachDict |rec|
    {
      if (rec.missing("func") || rec.missing("name")) return
      name := (Str)rec->name
      try
        acc[name] = Parser(Loc(file.toStr), rec->src.toStr.in).parseTop(name, rec)
      catch (Err e)
        echo("ERROR: Cannot load $name\n  $e")
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private static Str noEcho() { ShellContext.noEcho }

  private static ShellContext cx() { AxonContext.curAxon }

  private static Int maxStr(Str[] strs)
  {
    strs.reduce(0) |acc,s| { s.size.max(acc) }
  }

  private static Bool isNoDoc(TopFn f)
  {
    if (f.meta.has("nodoc")) return true
    if (f is FantomFn) return ((FantomFn)f).method.hasFacet(NoDoc#)
    return false
  }

  private static Str? funcDoc(TopFn f)
  {
    doc := f.meta["doc"] as Str
    if (doc != null) return doc.trimToNull
    if (f is FantomFn) return ((FantomFn)f).method.doc
    return null
  }

  private static Str? docSummary(Str t)
  {
    // this code is copied from defc::CFandoc - should be moved into haystack
    if (t.isEmpty) return ""

    semicolon := t.index(";")
    if (semicolon != null) t = t[0..<semicolon]

    colon := t.index(":")
    while (colon != null && colon + 1 < t.size && !t[colon+1].isSpace)
      colon = t.index(":", colon+1)
    if (colon != null) t = t[0..<colon]

    period := t.index(".")
    while (period != null && period + 1 < t.size && !t[period+1].isSpace)
      period = t.index(".", period+1)
    if (period != null) t = t[0..<period]

    return t.replace("\n", " ").trim
  }

}

