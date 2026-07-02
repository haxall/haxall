# Know Xeto

Xeto is a data modeling language for defining typed data structures.
It defines *specs* (type definitions) and *instances* (data conforming
to specs), organized into versioned modules called *libs*.

# Specs

Specs define the shape of data. Two fundamental kinds: scalars
(atomic string-encoded values) and dicts (compound types with slots).

```xeto
// scalar type
SocialSecurityNumber: Scalar <pattern:"\\d{3}-\\d{2}-\\d{4}">

// dict type with slots
Person: Dict <sealed, icon:"user"> {
  name: Str
  age: Number?
  height: Number <quantity:"length", minVal:0>
}
```

Spec names must start with an uppercase ASCII letter and use camelCase.

All scalar values are fundamentally strings. You can omit quotes when
the scalar string starts with ASCII digit and contains only digits, `-`,
or number unit chars.

```xeto
// these are equivalent
x: Number "100kW"
x: Number 100kW

// these are equivalent
d: Date "2024-03-14"
d: Date 2024-03-14
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

# Maybe Types

The `?` suffix is sugar for `<maybe>` meta. Omitting `?` means required:

```xeto
User: Dict {
  name: Str           // required
  email: Str?         // optional
  phone: Str <maybe>  // equivalent long form
}
```

Subtypes can narrow maybe to non-maybe (optional to required) but not
the reverse.

# Inheritance

Specs inherit slots and meta from a supertype:

```xeto
Foo: Dict {
  a: Str
  b: Date
}

// Bar inherits 'a' and 'b', adds 'c'
Bar: Foo {
  c: Number
}
```

Override a slot to narrow its type (must be covariant):

```xeto
Base: Dict {
  num: Number
}

// Int is a subtype of Number, so this is valid
Specific: Base {
  num: Int <minVal:0>
}
```

# Meta

Metadata is declared between angle brackets `<>`. Meta annotates
specs and slots with additional information:

```xeto
// spec-level meta
Person: Dict <abstract, sealed, icon:"user"> {

  // slot-level meta
  age: Number <minVal:0, maxVal:150>
  height: Number <quantity:"length">
}
```

Common built-in meta:
- `abstract` - cannot be instantiated directly
- `sealed` - cannot be subtyped
- `maybe` (or `?` sugar) - slot is optional
- `val` - default value
- `invariant` - value must match exactly
- `minVal` / `maxVal` - numeric bounds
- `quantity` / `unit` - unit constraints
- `pattern` - regex constraint for scalars
- `nonEmpty` - string/list must be non-empty
- `of` - parameterize List, Ref, Query item type
- `doc` - documentation (auto-set from `//` comments)
- `global` (or `*` sugar) - global slot constraint

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

Every spec has a globally unique qname: `{lib}::{Name}`.

```xeto
sys::Str                    // qname
Str                         // simple name (resolved via namespace)
ph.equips::NaturalGasMeter  // qname with dotted lib
NaturalGasMeter             // simple name
```

Slot qnames use dot: `sys::LibDepend.lib`

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

Closed set of string values:

```xeto
Suit: Enum {
  clubs
  diamonds
  hearts
  spades
}
```

Use `key` meta when string values differ from slot names:

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
  color: Color  // required: exactly one of red/green/blue
}

Car: Dict {
  color: Color? // optional: zero or one
}

Car: Dict {
  color: Color <multiChoice> // multiple allowed
}
```

# Globals

Global slots enforce consistent usage of a tag across all subtypes.
Declared with `*` prefix:

```xeto
Person: Dict {
  *height: Number <quantity:"length", minVal:0>
}

// Any subtype using 'height' must conform to the global constraint
Athlete: Person {
  height: Number  // inherits quantity:"length", minVal:0
}
```

# Mixins

Extend existing specs from another lib via late binding.
Mixin names use `+` prefix:

```xeto
// add meta to a spec from another lib
+Person <icon:"user">

// add meta to an existing slot
+Person {
  age: <icon:"calendar">
}

// add a new slot
+Person {
  orgRef: Ref <of:Org>
}
```

# Constraints

```xeto
Foo: Dict {
  // number constraints
  percent: Number <minVal:0, maxVal:100, unit:"%">
  power: Number <quantity:"power">

  // string constraints
  name: Str <nonEmpty>
  phone: Str <minVal:7, maxVal:10>
  ssn: Str <pattern:"\\d{3}-\\d{2}-\\d{4}">

  // list constraints
  tags: List <nonEmpty, of:Str>
  items: List <minSize:2, maxSize:5>
}
```

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

Directory structure:

```
src/xeto/
  acme.assets/       // lib name from directory
    lib.xeto         // pragma (required)
    specs.xeto       // type definitions
    instances.xeto   // instance data
```

Lib names: lowercase, dots as separators, globally unique.

# Comments and Documentation

```xeto
// Single line comment becomes 'doc' meta on the next spec/slot

// User account for the system
User: Dict {
  // Full legal name
  name: Str
}
```

# Scalars in Instance Data

Scalars are encoded as strings. Number literals include units:

```xeto
@example: Sensor {
  dis: "Zone Temp"
  kind: "Number"
  unit: "°F"
  minVal: Number 0
  maxVal: Number 100
  area: Number "2300ft²"
  installed: Date "2024-03-14"
  coord: Coord "C(37.55,-77.45)"
}
```

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

- Spec names: UpperCamelCase
- Slot/tag names: lowerCamelCase
- Use `?` suffix for optional slots (not `<maybe>`)
- Use `*` prefix for globals (not `<global>`)
- Use `//` comments for documentation
- Keep specs focused - prefer composition via inheritance
- Marker tags model boolean presence: `{site}` not `{site: true}`

