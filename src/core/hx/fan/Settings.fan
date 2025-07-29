//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Jun 2021  Brian Frank  Create
//

using concurrent
using xeto
using haystack

**
** Settings wraps a dict that maps tags to statically typed fields
** for extension settings.  To use this API:
**   1. Create subclass of Settings
**   2. Annotate const instance fields with [@Setting]`Setting`
**   3. Create constructor with Dict and it-block callback
**
** The following coercions are supported:
**   - Int field from Number tag
**   - Duration field from Number tag
**   - Bool field from Marker tag
**
** Example:
**
**    const class ExampleSettings : Settings
**    {
**      static new wrap(Dict d, |Str|? onErr := null) { create(ExampleRec#, d, onErr) }
**
**      new make(Dict d, |This| f) : super(d) { f(this) }
**
**      @Setting const Int limit := 99
**
**      @Setting const Duration timeout := 3sec
**    }
**
@Js
const class Settings : Dict
{
  ** Factory to create for given type and dict to wrap.  Invalid
  ** tag values are logged to the given callback if provided.
  static Settings create(Type type, Dict meta, |Str|? onErr := null)
  {
    sets := Field:Obj?[:]
    type.fields.each |field|
    {
      // skip if not annotated with facet
      if (!field.hasFacet(Setting#)) return

      // check if configured in wrapped dict
      val := meta[field.name]
      if (val == null) return

      // convenience for Int/Duration fields
      if (field.type == Int# && val is Number)
        val = ((Number)val).toInt
      else if (field.type == Duration# && val is Number && ((Number)val).isDuration)
        val = ((Number)val).toDuration
      else if (field.type == Bool# && val === Marker.val)
        val = true

      // attempt to map from tag type to field type
      if (val.typeof.fits(field.type.toNonNullable))
        sets[field] = val
      else if (onErr != null)
        onErr("Invalid val $field.qname.toCode: $field.type != $val.typeof")
    }
    return type.make([meta, Field.makeSetFunc(sets)])
  }

  ** Sub constructor.
  new make(Dict meta) { this.metaRef = meta }

  ** Wrapped dict for this instance
  Dict meta() { metaRef }
  private const Dict metaRef

  ** Get a tag from wrapped dict
  @Operator override Obj? get(Str n) { meta.get(n) }

  ** Return if wrapped dict is empty
  override Bool isEmpty() { meta.isEmpty }

  ** Return if wrapped dict has given tag
  override Bool has(Str n) { meta.has(n) }

  ** Return if wrapped dict is missing given tag
  override Bool missing(Str n) { meta.missing(n) }

  ** Iterate the wrapped dict tags
  override Void each(|Obj, Str| f) { meta.each(f) }

  ** Iterate the wrapped dict tags until callback returns non-null
  override Obj? eachWhile(|Obj, Str->Obj?| f) { meta.eachWhile(f) }

  ** Trap on the wrapped dict
  override Obj? trap(Str n, Obj?[]? a := null) { meta.trap(n, a) }
}

**************************************************************************
** Setting
**************************************************************************

**
** Facet to annotate a `Settings` field.
**
@Js
facet class Setting
{
  ** Is restart required before a change takes effect
  @NoDoc const Bool restart

  ** Meta data for the def encoded as a Trio string
  const Str meta := ""

  ** Decode into meta tag name/value pairs
  @NoDoc Void decode(|Str name, Obj val| f)
  {
    if (restart) f("restart", Marker.val)
    if (!meta.isEmpty) TrioReader(meta.in).readDict.each |v, n| { f(n, v) }
  }
}

