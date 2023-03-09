//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Jan 2023  Brian Frank  Creation
//

using util
using data
using haystack
using xeto::Printer
using axon
using def
using hx

**
** Shell context
**
internal class ShellContext : HxContext
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make(OutStream out)
  {
    this.out   = out
    this.data  = DataEnv.cur
    this.funcs = loadFuncs
    this.rt    = ShellRuntime()
    this.user  = ShellUser()

    importDataLib("sys")
    importDataLib("ph")
  }

  static Str:TopFn loadFuncs()
  {
    acc := Str:TopFn[:]
    acc.addAll(FantomFn.reflectType(CoreLib#))
    acc.addAll(FantomFn.reflectType(ShellFuncs#))
    acc.addAll(FantomFn.reflectType(HxCoreFuncs#))
    return acc
  }

//////////////////////////////////////////////////////////////////////////
// Shell
//////////////////////////////////////////////////////////////////////////

  ** Run the iteractive prompt+eval loop
  Int runInteractive()
  {
    out.printLine("Axon shell v${typeof.pod.version} ('?' for help, 'quit' to quit)")
    while (!isDone)
    {
      try
      {
        expr := prompt
        if (!expr.isEmpty) run(expr)
      }
      catch (AxonErr e)
      {
        err(e.msg, e.cause)
      }
      catch (Err e)
      {
        err("Internal error", e)
      }
    }
    return 0
  }

  ** Run the given expression and handle errors/output
  Int run(Str expr)
  {
    // wrap list of expressions in do/end block
    if (expr.contains(";") || expr.contains("\n"))
      expr = "do\n$expr\nend"

    // evaluate the expression
    Obj? val
    try
    {
      val = eval(expr)
    }
    catch (EvalErr e)
    {
      err(e.msg, e.cause)
      return 1
    }

    // print the value if no echo
    if (val !== noEcho) print(val)

    // save last value as "it"
    if (val != null && val != noEcho) defOrAssign("it", val, Loc.eval)
    return 0
  }

  ** Prompt user for input
  private Str prompt()
  {
    // prompt for one or more lines
    expr := Env.cur.prompt("axon> ").trim

    // if it looks like expression is incomplete, then
    // prompt for additional lines until empty
    if (isMultiLine(expr))
    {
      x := StrBuf().add(expr).add("\n")
      while (true)
      {
        next := Env.cur.prompt("..... ")
        if (next.trim.isEmpty) break
        x.add(next).add("\n")
      }
      expr = x.toStr
    }

    // check for special commands
    switch (expr)
    {
      case "?":
      case "help": return "help()"
      case "bye":
      case "exit":
      case "quit": return "quit()"
    }

    return expr
  }

  ** Return if we should enter multi-line input mode
  private Bool isMultiLine(Str expr)
  {
    if (expr.endsWith("do")) return true
    if (expr.endsWith("{")) return true
    return false
  }

  ** Print the value to the stdout
  Void print(Obj? val, Obj? opts := null)
  {
    data.print(val, out, opts)
  }

  ** Log evaluation error
  private Obj? err(Str msg, Err? err := null)
  {
    str := errToStr(msg, err)
    if (!str.endsWith("\n")) str += "\n"
    Printer(data, out, data.dict0).warn(str)
    return null
  }

  ** Format evaluation error trace
  private Str errToStr(Str msg, Err? err)
  {
    str := "ERROR: $msg"
    if (err == null) return str
    if (err is FileLocErr) str += " [" + ((FileLocErr)err).loc + "]"
    if (showTrace) str += "\n" + err.traceToStr
    else if (!str.contains("\n")) str += "\n" + err.toStr
    return str
  }

  ** Flag for full stack trace dumps
  Bool showTrace := false

  ** Sentinel value for no echo
  static const Str noEcho := "_no_echo_"

  ** Standout output stream
  OutStream out { private set }

  ** Flag to terminate the interactive loop
  Bool isDone := false

//////////////////////////////////////////////////////////////////////////
// HxContext
//////////////////////////////////////////////////////////////////////////

  ** Runtime
  override const ShellRuntime rt

  ** Def namespace
  override Namespace ns() { rt.ns }

  ** In-memory folio database
  override ShellFolio db() { rt.db }

  ** Current user
  override const HxUser user

  ** No session available
  override HxSession? session(Bool checked := true)
  {
    if (checked) throw SessionUnavailableErr("ShellContext")
    return null
  }

  ** Return empty dict
  override Dict about() { Etc.dict0 }

//////////////////////////////////////////////////////////////////////////
// HaystackContext
//////////////////////////////////////////////////////////////////////////

  ** Dereference an id to an record dict or null if unresolved
  override Dict? deref(Ref id) { db.readById(id, false) }

  ** Return inference engine used for def aware filter queries
  override once FilterInference inference() { MFilterInference(ns) }

  ** Return contextual data as dict
  override Dict toDict()
  {
    tags := Str:Obj[:]
    tags["axonsh"] = Marker.val
    tags["locale"] = Locale.cur.toStr
    tags["username"] = user.username
    tags["userRef"] = user.id
    return Etc.makeDict(tags)
  }

//////////////////////////////////////////////////////////////////////////
// FolioContext
//////////////////////////////////////////////////////////////////////////

  ** Return if context has read access to given record
  override Bool canRead(Dict rec) { true }

  ** Return if context has write (update/delete) access to given record
  override Bool canWrite(Dict rec) { true }

  ** Return an immutable thread safe object which will be passed thru
  ** the commit process and available via the FolioHooks callbacks.
  ** This is typically the User instance.  HxContext always returns user.
  override Obj? commitInfo() { user }

//////////////////////////////////////////////////////////////////////////
// AxonContext
//////////////////////////////////////////////////////////////////////////

  ** Map of installed functions
  const Str:TopFn funcs

  ** Find top-level function by qname or name
  override Fn? findTop(Str name, Bool checked := true)
  {
    f := funcs[name]
    if (f != null) return f
    if (checked) throw UnknownFuncErr(name)
    return null
  }

  ** Resolve dict by id - used by trap on Ref
  override Dict? trapRef(Ref id, Bool checked := true)
  {
    db.readById(id, checked)
  }

//////////////////////////////////////////////////////////////////////////
// Data Env
//////////////////////////////////////////////////////////////////////////

  const DataEnv data

  Str:DataLib libs := [:]

  DataLib importDataLib(Str qname)
  {
    lib := libs[qname]
    if (lib == null)
    {
      libs[qname] = lib = data.lib(qname)
    }
    return lib
  }

  DataType? findType(Str name, Bool checked := true)
  {
    acc := DataType[,]
    libs.each |lib| { acc.addNotNull(lib.slot(name, false)) }
    if (acc.size == 1) return acc[0]
    if (acc.size > 1) throw Err("Ambiguous types for '$name' $acc")
    if (checked) throw UnknownTypeErr(name)
    return null
  }

//////////////////////////////////////////////////////////////////////////
// TODO
//////////////////////////////////////////////////////////////////////////

  File resolveFile(Uri uri)
  {
    File(uri, false)
  }


}