//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Sep 2026  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** ValidateFuncRule checks a rule by calling the xeto func which tagged
** itself with the rule's id.  The func is called as 'func(spec, val)' and
** returns null or an empty list when the value is ok, otherwise a dict
** per problem or a list of them.  A 'slot' tag reports the item against
** that tag of the dict; the remaining tags are msg template args.
**
** The func needs a context to run in, so these rules do not run when
** compiling libs.
**
@Js
const class ValidateFuncRule : ValidateRule
{
  new make(ValidateRuleInit init, Spec func) : super(init)
  {
    this.func = func
  }

  ** Func spec to call
  const Spec func

  override Str? impl() { func.func.qname }

  override Void onCheck(ValidateState s)
  {
    // funcs need a runtime to call them; compiling a lib has none
    if (XetoContext.curXeto(false) == null) return

    res := func.func.thunk.callList([s.spec, s.val])
    if (res == null) return
    if (res is List) return ((List)res).each |x| { emitItem(s, toItem(x)) }
    emitItem(s, toItem(res))
  }

  ** Report one result dict at its slot or the rule's own position
  private Void emitItem(ValidateState s, Dict item)
  {
    slot := item["slot"] as Str
    args := Etc.dictRemove(item, "slot")
    if (slot == null) s.emit(args)
    else s.emitOn(slot, args)
  }

  ** Coerce one func result to a dict of msg args
  private Dict toItem(Obj? x)
  {
    x as Dict ?: throw Err("$qname func must return dict: ${x?.typeof}")
  }
}
