//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Jun 2021  Brian Frank  Create
//

using concurrent

**
** TypedDict wraps a dict that maps tags to statically typed fields.
** To use this API:
**   1. Create subclass of TypedDict
**   2. Annotate const instance fields with [@TypedTag]`TypedTag`
**   3. Create constructor with Dict and it-block callback
**   4. Optionally create convenience factory that calls `create`
**
** The following coercions are supported:
**   - Int field from Number tag
**   - Duration field from Number tag
**   - Bool field from Marker tag
**
** Example:
**
**    const class ExampleRec : TypedDict
**    {
**      static new wrap(Dict d, |Str|? onErr := null) { create(ExampleRec#, d, onErr) }
**
**      new make(Dict d, |This| f) : super(d) { f(this) }
**
**      @TypedTag const Int limit := 99
**
**      @TypedTag const Duration timeout := 3sec
**    }
**
@Js
const class TypedDict : Dict
{
  ** Factory to create for given type and dict to wrap.  Invalid
  ** tag values are logged to the given callback if provided.
  static TypedDict create(Type type, Dict meta, |Str|? onErr := null)
  {
    sets := Field:Obj?[:]
    type.fields.each |field|
    {
      // skip if not annotated with facet
      if (!field.hasFacet(TypedTag#)) return

      // check if configured in wrapped dict
      val := meta[field.name]
      if (val == null) return

      // convenience for Int/Duration fields
      if (field.type == Int# && val is Number)
        val = ((Number)val).toInt
      else if (field.type == Duration# && val is Number)
        val = ((Number)val).toDuration(false) ?: val
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
  @Operator override Obj? get(Str n, Obj? def := null) { meta.get(n, def) }

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
** TypedTag
**************************************************************************

**
** Facet to annotate a `TypedDict` field.
**
@Js
facet class TypedTag : Define
{
  ** Is restart required before a change takes effect
  @NoDoc const Bool restart

  ** Meta data for the def encoded as a Trio string
  const Str meta := ""

  ** Decode into meta tag name/value pairs
  @NoDoc override Void decode(|Str name, Obj val| f)
  {
    if (restart) f("restart", Marker.val)
    if (!meta.isEmpty) TrioReader(meta.in).readDict.each |v, n| { f(n, v) }
  }
}

