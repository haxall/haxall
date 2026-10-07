# Know Xeto

Xeto defines *specs* (types) and *instances* (data conforming to
specs), organized into versioned modules called *libs*.

# Specs

Specs define the shape of data. Two fundamental kinds: scalars
(atomic string-encoded values) and dicts (compound types with slots).

```xeto
// scalar type
SocialSecurityNumber: Scalar <pattern:"\\d{3}-\\d{2}-\\d{4}">

// dict type with spec meta and slot meta
Person: Dict <abstract, sealed, icon:"user"> {
  name: Str
  age: Number? <minVal:0, maxVal:150>
  height: Number <quantity:"length", minVal:0>
}
```

Spec names must start with an uppercase ASCII letter and use camelCase.

All scalar values are fundamentally strings. You can omit quotes when
the scalar string starts with ASCII digit and contains only digits, `-`,
or number unit chars:

```xeto
x: Number 100kW            // same as Number "100kW"
d: Date 2024-03-14         // same as Date "2024-03-14"
coord: Coord "C(37.55,-77.45)"
```

# Slot Specs

Slots are named fields inside a dict spec. Slot names start with
a lowercase letter. Each slot has a type and optional meta:

```xeto
Example: Dict {
  x: Int                      // required Int slot
  label: Str?                 // optional (maybe) slot
  color: Str <val:"red">      // slot with default value
  unit: Unit <invariant> "%"  // invariant: fixed value required
}
```

The `?` suffix is sugar for `<maybe>` meta; prefer `?`. Subtypes can
narrow maybe to non-maybe (optional to required) but not the reverse.

# Inheritance

Specs inherit slots and meta from a supertype. Override a slot to
narrow its type (must be covariant):

```xeto
Base: Dict {
  a: Str
  num: Number
}

// inherits 'a', narrows 'num' (Int is a subtype of Number), adds 'c'
Specific: Base {
  num: Int <minVal:0>
  c: Date
}
```

# Meta

Common built-in meta:
- `abstract` - cannot be instantiated directly
- `sealed` - cannot be subtyped
- `maybe` (or `?` sugar) - slot is optional
- `val` - default value
- `invariant` - value must match exactly
- `minVal` / `maxVal` - inclusive numeric bounds (numbers only)
- `minSize` / `maxSize` - inclusive length bounds for strings and lists
- `quantity` / `unit` - unit constraints
- `pattern` - regex constraint for scalars
- `nonEmpty` - string must be non-empty when trimmed (strings only;
  use `minSize:1` for lists)
- `of` - parameterize List, Ref, Query item type
- `doc` - documentation (auto-set from `//` comments on the line
  before a spec or slot)
- `global` (or `*` sugar) - global slot

# Instances

Instances are data objects that conform to a spec. Declared with
`@id` prefix and a spec type:

```xeto
@floor-2: Floor {
  dis: "Floor 2"
}

@room-204: Room {
  dis: "Room 204"
  spaceRef: @floor-2
}
```

Non-maybe markers from the spec are automatically included.
The instances above compile to dicts with `space`, `floor`,
`room` markers inherited from their specs.

## Nested Instances

Instances can be nested. Nested dicts can have a slot name,
a top-level `@id`, or both:

```xeto
// named slots only
@toolbar: Toolbar {
  save: Button { text:"Save" }
  exit: Button { text:"Exit" }
}

// nested with their own ids (auto-generated slot names)
@toolbar: Toolbar {
  @save-button: Button { text:"Save" }
  @exit-button: Button { text:"Exit" }
}

// both slot name and id
@toolbar: Toolbar {
  save @save-button: Button { text:"Save" }
}
```

# Qualified Names

Every spec has a globally unique qname: `{lib}::{Name}`, such as
`sys::Str` or `ph.equips.sugar::NaturalGasMeter`; the simple name
resolves via the namespace. Slot qnames use dot: `sys::LibDepend.lib`

# Core Types (sys lib)

Roots:
- `Obj` - root of all types
- `Scalar` - base for atomic types
Numeric: `Number`, `Int`, `Float`, `Duration`
Temporal: `Date`, `Time`, `DateTime`, `Span`
Text: `Str`, `Uri`, `Enum`, `Filter`, `Buf`
References: `Ref`, `MultiRef`
Singletons: `Bool`, `Marker`, `None`, `NA`

Collections:
- `Dict` - associative map (base for most compound types)
- `List` - ordered sequence (parameterize with `of`)
- `Grid` - two-dimensional table
- `Collection` - abstract base for collections

Special:
- `Entity` - dict with `id` and `spec` slots
- `Func` - function signature with `returns` slot
- `Funcs` - interface for function collections
- `Choice` - exclusive marker taxonomy
- `Query` - named dataset definition

# Lists

Parameterize with `of` meta. Lists use `{}` in instance data (not `[]`):

```xeto
// spec with a typed list slot
Foo: Dict {
  numbers: List <of:Number>
}

// instance - items inferred as Number from slot spec
@foo-1: Foo {
  numbers: { 2, 3, 4 }
}
```

`List` is sealed - you cannot subtype it.

# Enums

Closed set of string values. Use `key` meta when string values
differ from slot names:

```xeto
Suit: Enum {
  clubs    <key:"Clubs",    color:"black">
  diamonds <key:"Diamonds", color:"red">
  hearts   <key:"Hearts",   color:"red">
  spades   <key:"Spades",   color:"black">
}
```

# Choices

Exclusive marker taxonomy for "adjective" relationships:

```xeto
Color: Choice
Red: Color { red }
Green: Color { green }
Blue: Color { blue }

Car: Dict {
  color: Color                // required: exactly one of red/green/blue
  trim: Color?                // optional: zero or one
  stripes: Color <multiChoice> // multiple allowed
}
```

# Globals

Global slots, declared with a `*` prefix, enforce consistent typing of
a tag across all subtypes and their instance data:

```xeto
Person: Dict {
  *height: Number <quantity:"length", minVal:0>
}

Athlete: Person { height: Number }   // required; inherits global meta
Coach: Person { height: Number? }    // optional
Fan: Person { height: 180cm }        // value only: type inferred, optional
Bad: Person { height: Str }          // error: not covariant with global
```

Globals are implicitly maybe - declaring `*height: Number?` is an
error. Requiredness is decided where a subtype declares the slot.

# Mixins

Extend existing specs from another lib via late binding.
Mixin names use `+` prefix:

```xeto
+Person <icon:"user"> {
  age: <icon:"calendar">   // add meta to an existing slot (no type)
  orgRef: Ref <of:Org>     // add a new slot
  *badge: Str              // add a global
}
```

Mixin slots and globals resolve only for libs that declare the
mixin's lib as a dependency.

# Libs

Libs are versioned modules. Directory name determines lib name.
Every lib must have a `lib.xeto` pragma file:

```xeto
pragma: Lib <
  doc: "My library"
  version: "1.0.0"
  depends: {
    { lib: "sys", versions: "1.x.x" }
    { lib: "ph",  versions: "5.x.x" }
  }
  org: {
    dis: "Acme, Inc"
    uri: "https://acme.com/"
  }
>
```

Lib names: lowercase, dots as separators, globally unique.

# Heredocs

Multi-line string values use triple-dash `---` heredoc syntax.
The content between `---` markers is the literal string value:

```xeto
@myFunc: Func {
  x: Number
  y: Number
  src: Axon <axon:---
    do
      z: x + y
      z * 2
    end
  --->
}
```

Heredocs are often used for axon code in meta as shown above.  If the
content contains "---", then add additional "-" to the heredoc delimiters
until there is no conflict.

Triple-quoted strings `"""` are an alternative for shorter
multi-line values:

```xeto
@example: Dict {
  src: Axon <axon:"""(x) => x + 1""">
  notes: """
    Line one
    Line two
    """
}
```

For single-line values in meta, use a quoted string:

```xeto
Button { onAction: UiFunc <axon:"echo(event)"> }
```

# Style Notes

- Marker tags model boolean presence: `{site}` not `{site: true}`
- Keep specs focused - prefer composition via inheritance
