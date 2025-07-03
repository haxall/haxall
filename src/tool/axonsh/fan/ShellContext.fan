//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Jan 2023  Brian Frank  Creation
//

using util
using xeto
using haystack
using xetoEnv::Printer
using axon
using def
using hx

**
** Shell context
**
class ShellContext : HxContext
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make(OutStream out := Env.cur.out)
  {
    this.out   = out
    this.funcs = loadBuiltInFuncs
    this.rt    = ShellRuntime()
    this.user  = ShellUser()
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
      catch (SyntaxErr e)
      {
        err("Syntax Error: $e.msg")
      }
      catch (EvalErr e)
      {
        err(e.msg, e.cause)
      }
      catch (Err e)
      {
        err(e.toStr, e)
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
  Void print(Obj? val, Dict? opts := null)
  {
    printer(opts).print(val)
  }

  ** Log evaluation error
  private Obj? err(Str msg, Err? err := null)
  {
    str := errToStr(msg, err)
    if (!str.endsWith("\n")) str += "\n"
    printer.warn(str)
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
  Bool showTrace := true

  ** Sentinel value for no echo
  static const Str noEcho := "_no_echo_"

  ** Standout output stream
  OutStream out { private set }

  ** Create Xeto printer for output stream
  Printer printer(Dict? opts := null) { Printer(xeto, out, opts ?: Etc.dict0) }

  ** Flag to terminate the interactive loop
  Bool isDone := false

//////////////////////////////////////////////////////////////////////////
// HxContext
//////////////////////////////////////////////////////////////////////////

  ** Runtime
  override const ShellRuntime rt

  ** Def namespace
  override DefNamespace ns() { rt.ns }

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
// DataContext
//////////////////////////////////////////////////////////////////////////

  ** Read a data record by id
  override Dict? xetoReadById(Obj id)
  {
    db.readById(id, false)
  }

  ** Read all the records with a given tag name/value pair
  override Obj? xetoReadAllEachWhile(Str filter, |xeto::Dict->Obj?| f)
  {
    db.readAllEachWhile(Filter(filter), Etc.dict0, f)
  }

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
    return Etc.dictMerge(super.toDict, tags)
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
  Str:TopFn funcs

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

  private static Str:TopFn loadBuiltInFuncs()
  {
    acc := Str:TopFn[:]
    acc.addAll(FantomFn.reflectType(CoreLib#))
    acc.addAll(FantomFn.reflectType(ShellFuncs#))
    acc.addAll(FantomFn.reflectType(HxCoreFuncs#))
    acc.addAll(FantomFn.reflectType(Type.find("hxXeto::XetoFuncs")))
    acc.addAll(FantomFn.reflectType(Type.find("hxIO::IOFuncs")))
    return acc
  }

//////////////////////////////////////////////////////////////////////////
// TODO
//////////////////////////////////////////////////////////////////////////

  File resolveFile(Uri uri)
  {
    File(uri, false)
  }

}

