//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Oct 2009  Brian Frank  Creation
//   1 Jan 2016  Brian Frank  Refactor into axon pod
//

using concurrent
using haystack

**
** AxonContext manages the environment of an Axon evaluation
**
@Js
abstract class AxonContext : HaystackContext
{

//////////////////////////////////////////////////////////////////////////
// Current
//////////////////////////////////////////////////////////////////////////

  ** Current context for actor thread
  @NoDoc static AxonContext? curAxon(Bool checked := true)
  {
    cx := Actor.locals[Etc.cxActorLocalsKey]
    if (cx != null) return cx
    if (checked) throw Err("No AxonContext available")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  @NoDoc new make()
  {
    stack.add(CallFrame.makeRoot(this))
  }

//////////////////////////////////////////////////////////////////////////
// Overrides
//////////////////////////////////////////////////////////////////////////

  ** Definition namespace
  abstract Namespace ns()

  ** Find top-level function by qname or name
  @NoDoc abstract Fn? findTop(Str name, Bool checked := true)

  ** Resolve dict by id - used by trap on Ref
  @NoDoc virtual Dict? trapRef(Ref ref, Bool checked := true) { throw UnsupportedErr() }

  ** Resolve dict by local or remote id
  @NoDoc virtual Dict? xqReadById(Ref ref, Bool checked := true) { throw UnsupportedErr() }

  ** Resolve toDateSpan default value
  @NoDoc virtual DateSpan toDateSpanDef() { DateSpan.today }

  ** Evaluate an expression or if a filter then readAll convenience
  @NoDoc virtual Obj? evalOrReadAll(Str src) { throw UnsupportedErr() }

  ** Data spec usings namespace
  @NoDoc once AxonUsings usings() { AxonUsings() }

/////////////////////////////////////////////////////////////////////////////
// Eval
//////////////////////////////////////////////////////////////////////////

  ** Parse Axon expression
  Expr parse(Str src, Loc loc := Loc.eval)
  {
    parser := Parser(loc, src.in)
    expr := parser.parse
    return expr
  }

  ** Lookup and call a function with the given arguments.  The arguments
  ** must be fully evaluated values such as Numbers, Dicts, Grids, etc.
  Obj? call(Str funcName, Obj?[] args)
  {
    evalToFunc(funcName).call(this, args)
  }

  ** Evaluate expression to a function expression
  Fn evalToFunc(Str src) { parse(src).evalToFunc(this) }

  ** Evaluate an Axon expression within this context.
  ** Convenience for 'evalExpr(parse(src, loc))'
  Obj? eval(Str src, Loc loc := Loc.eval)
  {
    evalExpr(parse(src, loc))
  }

  ** Evaluate an expression
  Obj? evalExpr(Expr expr)
  {
    try
      return expr.eval(this)
    catch (ReturnErr e)
      return ReturnErr.getVal
  }

//////////////////////////////////////////////////////////////////////////
// Heartbeat
//////////////////////////////////////////////////////////////////////////

  ** Get/set the timeout
  @NoDoc Duration? timeout
  {
    set
    {
      &timeout = it
      timeoutTicks = (it == null) ? Int.maxVal : Duration.nowTicks + it.ticks
    }
  }

  ** Default timeout to use across VM
  @NoDoc static const Duration timeoutDef := 1min

  ** Check background cancel/timeout state
  @NoDoc Void heartbeat(Loc loc)
  {
    // heartbeat callback for job cancel
    heartbeatFunc?.call

    // timeout
    if (Duration.nowTicks > timeoutTicks && timeout != null)
      throw EvalTimeoutErr(timeout, this, loc)
  }

//////////////////////////////////////////////////////////////////////////
// Call Stack
//////////////////////////////////////////////////////////////////////////

  ** Current function on top of call stack
  @NoDoc Fn? curFunc()
  {
    for (i:=stack.size-1; i>=0; --i)
    {
      f := stack[i]
      if (f.func.name != "curFunc")
        return f.func
    }
    return null
  }

  ** Push new call frame onto the stack with given loc/vars and route to Fn.doCall
  @NoDoc Obj? callInNewFrame(Fn func, Obj?[] args, Loc callLoc, Str:Obj? vars := Str:Obj?[:])
  {
    frame := CallFrame(this, func, args, callLoc, vars)
    stack.push(frame)
    try
      return func.doCall(this, args)
    finally
      stack.pop
  }

  ** Check security permissions to call given function
  @NoDoc virtual Void checkCall(Fn func) {}

//////////////////////////////////////////////////////////////////////////
// Variables
//////////////////////////////////////////////////////////////////////////

  ** Define or assign given variable
  @NoDoc Obj? defOrAssign(Str name, Obj? val, Loc loc)
  {
    f := stack.last
    if (f.has(name))
      return assign(name, val, loc)
    else
      return def(name, val, loc)
  }

  ** Define a new variable
  internal Obj? def(Str name, Obj? val, Loc loc)
  {
    f := stack.last
    if (f.has(name)) throw EvalErr("Symbol already bound '$name'", this, loc)
    return f.set(name, val)
  }

  ** Current frame on call stack
  internal CallFrame curFrame() { stack.last }

  ** Resolve a variable or raise exception if not bound
  internal Obj? resolve(Str name, Loc loc)
  {
    // find it in call stack frames
    frame := varFrame(name)
    if (frame != null) return frame.get(name)

    // resolve top-level function
    top := findTop(name, false)
    if (top != null) return top

    throw EvalErr("Unknown symbol '$name'", this, loc)
  }

  ** Safely get just a variable or return null (don't check
  ** for top-level functions, nor raise exception)
  internal Obj? getVar(Str name)
  {
    frame := varFrame(name)
    if (frame != null) return frame.get(name)
    return null
  }

  ** Assign to an existing variable
  internal Obj? assign(Str name, Obj? val, Loc loc)
  {
    // find it in call stack frames
    frame := varFrame(name)
    if (frame != null) return frame.set(name, val)

    throw EvalErr("Unknown symbol '$name'", this, loc)
  }

  ** Get the variables in scope
  @NoDoc Str:Obj? varsInScope()
  {
    curFunc := scopeCurFunc

    // walk stack bottom to top
    acc := Str:Obj?[:]
    for (i:=0; i<stack.size; ++i)
    {
      f := stack[i]
      if (f.isVisibleTo(curFunc))
      {
        f.each |v, n| { acc[n] = v }
      }
    }
    return acc
  }

  ** Resolve the frame with the given variable which is visible
  private CallFrame? varFrame(Str name)
  {
    // resolve variable on call stack
    curFunc := scopeCurFunc
    for (i:=stack.size-1; i>=0; --i)
    {
      f := stack[i]
      if (f.has(name) && f.isVisibleTo(curFunc))
        return f
    }
    return null
  }

  ** Get function we are using for current variable scope
  private Fn scopeCurFunc()
  {
    // get current function to determine lexical scope visibility
    // if lazy function then use the calling function
    curFunc := stack.last.func
    if (curFunc is LazyFantomFn) curFunc = stack[-2].func
    return curFunc
  }

//////////////////////////////////////////////////////////////////////////
// Trace
//////////////////////////////////////////////////////////////////////////

  ** Dump call stack trace to a string
  @NoDoc Str traceToStr(Loc errLoc, Dict? opts := null)
  {
    s := StrBuf()
    trace(errLoc, s.out, opts)
    return s.toStr
  }

  ** Dump call stack trace to a grid
  @NoDoc Grid traceToGrid(Loc errLoc, Dict? opts := null)
  {
    gb := GridBuilder().addCol("name").addCol("file").addCol("line").addCol("vars")
    traceWalk(errLoc, opts) |name, loc, vars|
    {
      gb.addRow([name, loc.file, Number(loc.line), vars])
    }
    return gb.toGrid
  }

  ** Dump call stack trace to output stream
  @NoDoc Void trace(Loc errLoc, OutStream out := Env.cur.out, Dict? opts := null)
  {
    traceVars := opts != null && opts.has("vars")
    traceWalk(errLoc, opts) |name, loc, vars|
    {
      if (loc === Loc.unknown)
        out.printLine("  $name")
      else
        out.printLine("  $name ($loc)")

      if (traceVars)
        vars.each |v, n| { out.print("    $n: ").print(Expr.summary(v)).printLine }
    }
  }

  ** Walk the trace call stack
  @NoDoc Void traceWalk(Loc errLoc, Dict? opts, |Str name, Loc loc, Dict vars| f)
  {
    for (i:= stack.size-1; i>=1; --i)
    {
      frame := stack[i]
      func  := frame.func
      name  := func.name
      loc   := stack.getSafe(i+1)?.callLoc ?: errLoc
      f(name, loc, frame.toDict)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Caching
//////////////////////////////////////////////////////////////////////////

  ** Stash allows you to stash objects on the Context object
  ** during an Axon evaluation.  You should scope your string
  ** keys with your pod name to avoid naming collisions.
  Str:Obj? stash() { stashRef }
  private Str:Obj? stashRef := [:]

  ** Cache regular expression construction
  internal Regex toRegex(Obj s)
  {
    try
    {
      if (regex == null) regex = Str:Regex[:]
      r := regex[s]
      if (r == null) regex[s] = r = Regex.fromStr(s)
      return r
    }
    catch (CastErr e) throw CastErr("regex must be Str, not $s.typeof")
  }

  ** Create a snapshot of the call stack exactly as it is now.
  ** This allows closure functions to be stored away for lazy evaluation
  ** without loosing their scoping context.
  ** DO NOT USE THIS METHOD ANYMORE!
  ** TODO: this is only used in one spot: hisExt::Rollup
  @NoDoc virtual This clone() { throw UnsupportedErr() }
  @NoDoc protected This doClone(AxonContext that)
  {
    that.heartbeatFunc = this.heartbeatFunc
    that.timeoutTicks  = this.timeoutTicks
    that.stack         = this.stack.dup
    that.regex         = this.regex
    return that
  }

//////////////////////////////////////////////////////////////////////////
// Private Fields
//////////////////////////////////////////////////////////////////////////

  @NoDoc Func? heartbeatFunc
  private Int timeoutTicks := Int.maxVal
  private CallFrame[] stack := [,]
  private [Str:Regex]? regex
}

**************************************************************************
** CallFrame
**************************************************************************

**
** CallFrame manages the state/scope of function call
**
@Js
internal class CallFrame
{
  new make(AxonContext cx, Fn func, Obj?[] args, Loc callLoc, Str:Obj? vars)
  {
    this.cx      = cx
    this.func    = func
    this.callLoc = callLoc
    this.vars    = vars

    // bind parameter variables to arguments
    if (!func.isNative)
      func.params.each |param, i| { set(param.name, args[i]) }
  }

  new makeRoot(AxonContext cx)
  {
    this.cx      = cx
    this.func    = rootFunc
    this.callLoc = func.loc
    this.vars    = Str:Obj?[:]
  }

  Bool has(Str name) { vars.containsKey(name) }

  Void each(|Obj? v, Str n| f) { vars.each(f) }

  Dict toDict() { Etc.makeDict(vars) }

  Obj? get(Str name)
  {
    vars[name]
  }

  Obj? set(Str name, Obj? val)
  {
    vars[name] = val
    return val
  }

  Void remove(Str name) { vars.remove(name) }

  ** Does the given function have variable visibility into
  ** this frame's variables?  Only if the function is lexically
  ** scoped inside this frame's function.
  Bool isVisibleTo(Fn? f)
  {
    while (f != null)
    {
      if (this.func === f) return true
      f = f.outer
    }
    return this.func === rootFunc
  }

  override Str toStr() { "CallFrame $func.name [$callLoc]" }

  private static const Fn rootFunc := Fn(Loc("root"), "root", FnParam[,])
  private static const Str nullVal := "_CallFrame.null_"

  AxonContext cx { private set }
  const Loc callLoc
  const Fn func
  private Str:Obj? vars
 }

