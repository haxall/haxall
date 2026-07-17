# Know Axon

Axon is a functional scripting language for querying, transforming, and
analyzing data. It is dynamically typed, tag-oriented, and designed
around pipelines of function calls.

# Scalars

```axon
null                       // null
true false                 // Bool
123  -5  10_000  9.23kg    // Number (optional unit)
5.4e-45  74.2°F  5min      // Number with exponent or unit
"hello"  "line\n"          // Str (backslash escapes)
"""triple "quoted" str"""  // Str (triple-quote, multi-line)
r"\raw\string"             // Str (raw, no escapes)
`io/file.csv`              // Uri
2024-03-14                 // Date
8:30  14:05:30             // Time
0..100                     // Range
2024-03                    // Date Range (entire month)
@id                        // Ref
```

Numbers can have a unit: `100kW`, `72°F`, `5min`, `3600s`, `2300ft²`.
Construct DateTime with `dateTime(2024-03-14, 8:30, "New_York")`.

# Collections

Lists:

```axon
[]                 // empty
[1, 2, 3]          // number list
[4, "four", null]  // mixed types
```

There is no keyed list literal - `[a:1, b:2]` is an error. Use a
dict for keyed data, or `list.index()` to build a lookup.

Dicts:

```axon
{}                   // empty
{dis:"Bob", age:35}  // name/value pairs
{site}               // marker tag (value is marker)
{-site}              // remove tag
{"non id key": 123}  // quoted key
```

Grids are two-dimensional tables. Create from list of dicts:

```axon
[{dis:"A", area:2300ft²},
 {dis:"B", area:3100ft²}].toGrid
```

# Variables and Assignment

```axon
x: 5       // define variable with ':'
x = x + 1  // reassign with '=' (must already be defined)
```

# Operators

Precedence high to low:

```axon
x.y  x.y()  x->y  x[y]  // primary: dot call, trap, index
not x   -x              // unary
* /                     // multiplicative
+ -                     // additive
== != < <= >= > <=>     // comparison
and                     // logical and (short-circuit)
or                      // logical or (short-circuit)
=                       // assignment
```

Trap `->` throws on missing key; index `[]` returns null.

```axon
rec->dis    // throws UnknownNameErr if missing
rec["dis"]  // returns null if missing
```

Null propagates through math: `null + 2` evaluates to `null`.

# Lambdas and Functions

```axon
x => x * x         // single param (parens optional)
(x, y) => x + y    // multiple params
() => "hello"      // no params
(a, b:2) => a + b  // default param value
```

Define named functions:

```axon
add: (x, y) => x + y
add(2, 3)  >>  5
```

# Dot Calls (Pipelines)

Pipe the result of one function as the first arg to the next:

```axon
readAll(site).keepCols(["dis","area"])

// equivalent to:
keepCols(readAll(site), ["dis","area"])
```

Omit parens when no additional args: `today().year.toStr`

# Trailing Lambda

The last lambda argument can be placed outside the parens, but
only if the parens are present. It is safest to always pass the
lambda inside the parens to avoid ambiguity:

```axon
// safe: lambda inside parens (preferred)
list.sort((a, b) => a.size <=> b.size)
list.map(x => x * 2)
list.findAll(x => x > 10)

// also works: trailing lambda after empty parens
list.sort() (a, b) => a.size <=> b.size

// BROKEN: trailing lambda without parens
list.each (x) => echo(x)   // parse error
```

# Partial Application

Use `_` to create a new function with a bound argument:

```axon
add: (a, b) => a + b
inc: add(_, 1)  // creates (x) => add(x, 1)
inc(3)  >>  4
```

# Blocks

Use `do`/`end` for multi-expression bodies:

```axon
f: (a, b) => do
  c: a + b
  c * c
end
```

Last expression is the return value. Use `return` to short-circuit:

```axon
classify: (x) => do
  if (x < 10) return "small"
  if (x > 90) return "big"
  "medium"
end
```

# Control Flow

```axon
// if/else (is an expression that returns a value)
// there is no ternary operator - cond ? a : b is a syntax error
if (x > 0) "pos" else "non-pos"

// multi-line if/else
if (cond1) do
  ...
else if (cond2) do
  ...
else do
  ...
end

// throw
throw "something went wrong"
throw {dis:"error msg", code:404}

// try/catch (is an expression)
result: try parseNumber(s) catch 0
try do
  ...
catch (ex) do
  echo(ex->dis)
end
```

# Scoping and Closures

Axon uses lexical scoping. `do`, `if`, `try` blocks do NOT create new
scopes. A variable defined anywhere in a function is visible everywhere
in that function. Nested functions (closures) can access outer variables:

```axon
count: 0
list.each(x => count = count + 1)
```

# Filters

Filters are a declarative query language used with `read`, `readAll`,
and as shorthand expressions. They are NOT the same as Axon expressions.

```axon
site                           // has marker tag
not point                      // missing tag
equip and hvac                 // logical and
ahu or chiller                 // logical or
geoCity == "Chicago"           // string equality
curVal > 75                    // number comparison
equipRef == @abc123            // ref equality
siteRef->geoCity == "Chicago"  // ref path traversal
Meter                          // match by Xeto spec type
```

Used in code:

```axon
read(site and dis=="HQ")          // single rec (throws if not found)
readAll(point and equipRef==@id)  // all matching recs
readAll(ahu and siteRef==s->id)   // using variable in filter
```

# Qualified Names

Functions can be called with a library-qualified name:

```axon
hx.point::toPoints
geo::geoTz(val)
```

# Common Data Operations

## Strings

```axon
"hello".size                    >>  5
"hello".upper                   >>  "HELLO"
"a,b,c".split(",")              >>  ["a", "b", "c"]
"hello" + " world"              >>  "hello world"
"abcd".startsWith("ab")         >>  true
"root toot".replace("oo", "a")  >>  "rat tat"
```

A dollar sign in a Str literal is reserved for interpolation (which
is not supported) - escape it as `"\$"`.

There is no `Str()` constructor - use `toStr`. Triple-quote
continuation lines must indent to the column past the opening `"""`,
so prefer `\n` escapes or `lines.concat("\n")` to build multi-line
strings in code.

## Lists

```axon
list.size                       // length
list.first / list.last          // first/last item
list[0] / list[-1]              // index (negative from end)
list[1..-1]                     // slice
list.add(x) / list.addAll(xs)   // append (returns new list)
list.set(i, v)                  // replace at index
list.contains(x)                // membership test
list.sort / list.sortr          // sort / reverse sort
list.unique                     // unique values
list.concat(",")                // join to string
```

## Higher Order Functions (lists, dicts, grids)

```axon
list.each(x => echo(x))   // iterate
list.map(x => x * 2)      // transform
list.findAll(x => x > 0)  // filter
list.find(x => x > 10)    // first match
list.any(x => x > 0)      // any match?
list.all(x => x > 0)      // all match?
list.fold(sum)            // reduce
list.fold(max)            // max/min are fold funcs, not list.max
list.sort((a,b) => a.dis <=> b.dis)  // custom sort
```

## Dicts

```axon
d: {dis:"Bob", age:35}
d->dis              // "Bob" (throws if missing)
d["age"]            // 35 (null if missing)
d.has("age")        // true
d.missing("foo")    // true
d.names             // ["dis", "age"]
d.vals              // ["Bob", 35]
d.set("tag", val)   // add/update tag
d.remove("tag")     // remove tag
```

## Grids

```axon
g.size                            // row count
g.colNames                        // column names
g.first / g.last / g[0]           // row access
g.colToList("area")               // column as list
g.foldCol("area", sum)            // fold a column
g.sort("area") / g.sortr("area")  // sort by column
g.map(r => r.set("x", r->a + 1))  // transform rows
g.findAll(r => r->area > 2000)    // filter rows
g.addCol("name", r => expr)       // add computed column
g.keepCols(["a","b"])             // keep only named cols
g.removeCol("x")                  // remove column
g.renameCol("old","new")          // rename column
g.join(other, "key")              // join two grids
g.addMeta({title:"Sites"})        // grid-level meta
g.addColMeta("c", {dis:"Col"})    // column-level meta
g.unique("dis")                   // unique by column
```

`dis` is a computed display value, not a stored column - `r->dis` and
`g.colToList("dis")` throw UnknownNameErr. Use the `dis()` function
(`r.dis`), or `.toRecList` and read tags off the rec dicts.

Column names must be valid tag names (start lowercase, alphanumerics
only) - `toGrid` raises "Invalid col name" otherwise. When pivoting
display strings into columns, sanitize the key with `toTagName` and
attach the label as column meta:

```axon
key: site.dis.toTagName             // "Cary Town" -> "caryTown"
g.addColMeta(key, {dis:site.dis})   // human label for the column
```

## Dates and Times

```axon
today()                   // today's date
now()                     // current DateTime
yesterday()               // yesterday's date
today() + 7day            // date arithmetic
now() + 1hr               // datetime arithmetic
now().date / now().time   // extract date/time
today().year / .month / .day  // components
now().toTimeZone("UTC")   // convert timezone
thisWeek() / thisMonth()  // date spans
lastMonth() / pastWeek()  // date spans
2024-01-01..2024-01-31    // explicit date range
```

## Database Reads

```axon
read(site)                          // single rec
readAll(point and equipRef==@id)    // all matching
readById(@id)                       // by id
readAll(ahu and siteRef==site->id)  // cross-ref query
```

## Diffs and Commits

```axon
diff(null, {dis:"New", site}, {add}).commit  // add new rec
diff(rec, {area:5000ft²}).commit             // update existing rec
diff(rec, {-oldTag}).commit                  // remove tag
```

## I/O

```axon
ioReadCsv(`io/file.csv`)     // read CSV to grid
ioReadZinc(`io/file.zinc`)   // read Zinc to grid
```

## Regex

```axon
reMatches(r"AHU-(\d+)", "AHU-10")      // true
reFind(r"AHU-(\d+)", "x AHU-3 y")      // "AHU-3"
reGroups(r"(Clg|Hgt)-(\d+)", "Hgt-7")  // ["Hgt-7", "Hgt", "7"]
```

# Patterns

## Pipeline Pattern

Chain reads and transforms into pipelines:

```axon
readAll(site)
  .findAll(r => r->area > 1000ft²)
  .sort("area")
  .keepCols(["dis", "area"])
```

## Data Import Pattern

```axon
ioReadCsv(`io/data.csv`).map(row => do
  {dis: row->name,
   area: row->sqft.parseNumber.as(1ft²),
   site}
end)
```

## Batch Processing Pattern

```axon
readAll(equip).each(equip => do
  points: readAll(point and equipRef==equip->id)
  echo(equip.dis + ": " + points.size + " points")
end)
```

## Dict Accumulation Pattern

```axon
acc: {}
items.each(item => do
  acc = acc.set(item->name, item->val)
end)
```

## Null Guard Pattern

```axon
if (val == null) return null
result: doSomething(val)
if (result.isEmpty) return null
result.foldCol("v0", sum)
```

# Units

```axon
100kWh.to(1BTU)   // convert: 341,280 BTU
65°F.to(1°C)      // convert: 18.33 °C
65°F.as(1)        // strip unit: 65
65°F.as(1°C)      // relabel without converting: 65°C
isMetric(rec)     // true if rec uses metric units

unitdb()                                     // grid of all units: quantity, name, symbol
unitdb().findAll(r => r->quantity == "energy")  // units for a quantity
tzdb()                                       // grid of all timezones: name, fullName
```

Unit arithmetic rules:
- Same units: `12kg + 5kg` >> `17kg`
- Null unit carries: `12kg + 5` >> `17kg`
- Different units throw: `12kg + 5lb` >> UnitErr
- Temp subtraction: `75°F - 50°F` >> `25Δ°F`
- Derived units: `400kW * 2h` >> `800kWh`

# Function Declarations

Function names must be lowerCamelCase. Functions are declared in
two contexts:

In xeto libs, functions are slots inside a `+Funcs` mixin:

```xeto
+Funcs {
  mySiteCount: Func <axon:"() => readAll(site).size">
}
```

In the companion lib (per-project runtime), functions are managed
recs. Parse with `companionParseAxon`, then save with `companionAdd`
or `companionUpdate`:

```axon
// new function: parse then add
companionParseAxon("mySiteCount", "() => readAll(site).size").companionAdd

// update existing: read, merge changes, update
companionReadByName("mySiteCount").merge({axon:"() => readAll(site).size * 2"}).companionUpdate
```

See the `make-func` skill for full details on creating functions.

# Style Notes

- Prefer dot-call pipelines over nested function calls
- Use `->` when you expect the tag to exist; `[]` when it might not
- na() checks: `val == na()` or `val != na()`
- Unit conversion: `val.to(1kW)`, strip unit: `val.as(1)`
- Marker creation: `marker()` for programmatic use
- Avoid use of comments that contain "---" because it complicates heredocs

