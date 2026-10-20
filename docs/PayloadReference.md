# Payload reference

Everything a payload can contain. Every JSON example on this page is decoded by the test suite (`PayloadReferenceTests`), and every component, modifier, operator and action the runtime supports must be listed here. So this page can't drift from the code.

Most screens are written in SwiftUI and compiled ([Compiler](Compiler.md)). This page is for reading compiled output, writing payloads by hand, and building tools.

- [The payload](#the-payload)
- [Values, expressions and state paths](#values-expressions-and-state-paths)
- [Expression operators](#expression-operators)
- [Actions](#actions)
- [Components](#components)
- [Modifiers](#modifiers)
- [Options](#options)

## The payload

```json
{
  "schemaVersion": "1.0",
  "version": "2026-10-20.1",
  "state": { "count": 0, "todos": [] },
  "body": { "vStack": { "children": [ { "text": { "value": { "var": "count" } } } ] } },
  "views": { "footer": { "text": { "value": "Made with SwiftInjection" } } },
  "scripts": { "double": "(n) => n * 2" }
}
```

| Key | | |
|---|---|---|
| `schemaVersion` | required for loaded payloads | `"major.minor"`. A runtime accepts the same major version with a minor version at or below its own (this runtime: `1.1`). `swift-injection compile` writes the lowest version the payload needs, so payloads that don't use newer features still load in older apps. Additions are marked *schema 1.1* below. |
| `version` | optional | Your identifier for this content (a build number or date). Used to tell whether a remote payload is new. |
| `state` | optional | The screen's initial state: any JSON object. |
| `body` | required | The root view. |
| `views` | optional | Named views that `{"ref": "name"}` renders. |
| `scripts` | optional | JavaScript function expressions callable from actions and expressions (see `ScriptRuntime`). |

Every view and modifier key is optional unless marked **required**. `id` and `modifiers` are accepted on every component and left out when empty.

## Values, expressions and state paths

Wherever a value is shown or configured, you can give an **expression**:

- **A literal:** `"Hello"`, `12`, `true`, `null`, or an array of expressions.
- **A state value:** `{"var": "user.name"}`. Paths are dotted, and array indices are numbers (`{"var": "todos.0.title"}`). Use `{"var": ["user.name", "Anonymous"]}` for a default when the path is missing.
- **An object literal:** `{"object": {"name": {"var": "draft"}, "done": false}}`.
- **An operation:** a single-key object naming an operator, e.g. `{"add": [{"var": "count"}, 1]}`.

```json
{ "format": ["{0} of {1} done", { "count": { "var": "done" } }, { "count": { "var": "todos" } }] }
```

**State paths** are plain strings naming where something is read and written: bindings like `"text": "form.email"` or `"isOn": "settings.notify"`, and action targets like `{"set": "count", …}`.

**Locals.** Inside `forEach`, `list`, `picker` and `table`, the element is available as `item` (or the `itemName` you choose) and its position as `index`. Writes to `item.title` reach the real element. Inside `geometryReader`, `geometry.width`, `geometry.height` and `geometry.safeArea.top` etc. are available.

Expressions never crash. A failure (an unknown path, a type mismatch, division by zero) is reported to `StateStore.onError`, and that value falls back to a default.

## Expression operators

| Operator | Arguments | Result |
|---|---|---|
| `add` | numbers… | sum |
| `sub` | `[a, b]`, or `a` to negate | difference |
| `mul` | numbers… | product |
| `div` | `[a, b]` | quotient (an error if `b` is 0) |
| `mod` | `[a, b]` | remainder |
| `eq` | `[a, b]` | whether they're equal (any types, strictly; `1` isn't `"1"`) |
| `neq` | `[a, b]` | whether they differ |
| `gt` | `[a, b]` | `a > b` (two numbers or two strings) |
| `gte` | `[a, b]` | `a >= b` |
| `lt` | `[a, b]` | `a < b` |
| `lte` | `[a, b]` | `a <= b` |
| `and` | bools… | all true (stops at the first false) |
| `or` | bools… | any true (stops at the first true) |
| `not` | bool | the negation |
| `if` | `[condition, then, else]` | `then` or `else`; only the chosen branch is evaluated |
| `concat` | values… | their text joined |
| `format` | `[template, values…]` | the template with `{0}`, `{1}`, … replaced |
| `length` | string, array or object | its length |
| `count` | string, array or object | its length |
| `at` | `[array, index]` or `[object, key]` | the element |
| `call` | `["function", args…]` | the result of a host function or script (it can't change state) |

```json
{ "if": [{ "and": [{ "gt": [{ "var": "count" }, 0] }, { "not": { "var": "paused" } }] }, "Running", "Idle"] }
```

## Actions

Actions run in response to events (button taps, gestures, submits, …) as a list, applied as **one transaction**: later actions see earlier writes, the screen updates once, and if any action fails, none of them are applied.

### `set`

Writes an expression's value to a state path.

```json
[{ "set": "count", "to": { "add": [{ "var": "count" }, 1] } }, { "set": "item.done", "to": true }]
```

### `if`

Runs `then` or `else` (both optional).

```json
{ "if": { "gte": [{ "var": "count" }, 10] }, "then": [{ "set": "level", "to": "high" }], "else": [{ "set": "level", "to": "low" }] }
```

### `delay`

Runs actions after a number of seconds, as their own transaction.

```json
{ "delay": 1.5, "do": [{ "set": "showingToast", "to": false }] }
```

### `call`

Calls a script or a Swift host function registered on `StateStore.functions`. It can change state inside the transaction.

```json
{ "call": "addTodo", "args": [{ "var": "draft" }] }
```

## Components

A view is a single-key object naming its component: `{"text": {…}}`. Unknown components are skipped with a warning, so newer payloads still load in older apps.

### Text and images

### `text`

| Key | |
|---|---|
| `value` | **required.** The text (any expression; numbers and bools are shown as text) |

```json
{ "text": { "value": { "format": ["Hi {0}", { "var": "name" }] }, "modifiers": [{ "bold": {} }] } }
```

### `image`

The first source given is used, in order: `url` (loaded asynchronously), `systemName`, `name`. With none, a placeholder symbol is shown.

| Key | |
|---|---|
| `url` | Remote image URL |
| `systemName` | SF Symbol name |
| `name` | Asset name |
| `scale` | Scale for remote images (default 1) |
| `placeholder` | A view to show while a remote image loads |

```json
{ "image": { "systemName": { "if": [{ "var": "done" }, "checkmark.circle.fill", "circle"] } } }
```

### `label`

| Key | |
|---|---|
| `title`, `systemImage`, `image` | A title with an SF Symbol or an asset |
| `titleView`, `iconView` | Custom views instead |

```json
{ "label": { "title": "Settings", "systemImage": "gear" } }
```

### Layout

### `vStack`

Also `lazyVStack`, with the same keys.

| Key | |
|---|---|
| `children` | The views, top to bottom |
| `alignment` | Horizontal alignment (see [Options](#options)) |
| `spacing` | A number |
| `pinnedViews` | Lazy stacks only: `["sectionHeaders", "sectionFooters"]` |

```json
{ "vStack": { "alignment": "leading", "spacing": 8, "children": [{ "text": { "value": "One" } }, { "text": { "value": "Two" } }] } }
```

### `lazyVStack`

Like `vStack`, created as needed while scrolling.

```json
{ "lazyVStack": { "pinnedViews": ["sectionHeaders"], "children": [] } }
```

### `hStack`

Also `lazyHStack`. Same keys as `vStack`, with vertical `alignment`.

```json
{ "hStack": { "alignment": "firstTextBaseline", "children": [{ "image": { "systemName": "star" } }, { "text": { "value": "Starred" } }] } }
```

### `lazyHStack`

```json
{ "lazyHStack": { "spacing": 4, "children": [] } }
```

### `zStack`

| Key | |
|---|---|
| `children` | Back to front |
| `alignment` | Two-dimensional alignment, e.g. `topLeading` |

```json
{ "zStack": { "alignment": "bottomTrailing", "children": [{ "color": { "color": "#FF007AFF" } }, { "text": { "value": "New" } }] } }
```

### `grid`

| Key | |
|---|---|
| `children` | Usually `gridRow`s |
| `alignment`, `horizontalSpacing`, `verticalSpacing` | |

```json
{ "grid": { "horizontalSpacing": 8, "children": [{ "gridRow": { "children": [{ "text": { "value": "A" } }, { "text": { "value": "B" } }] } }] } }
```

### `gridRow`

| Key | |
|---|---|
| `children` | One cell each |
| `alignment` | Vertical alignment |

```json
{ "gridRow": { "alignment": "top", "children": [] } }
```

### `lazyVGrid`

Also `lazyHGrid`, with `rows` instead of `columns` and vertical `alignment`.

| Key | |
|---|---|
| `columns` | **required.** Grid items: `{"size": "fixed", "value": 100}`, `{"size": "flexible", "minimum": 50}`, `{"size": "adaptive", "minimum": 80, "maximum": 120}`, each with optional `spacing` and `alignment` |
| `children`, `alignment`, `spacing`, `pinnedViews` | |

```json
{ "lazyVGrid": { "columns": [{ "size": "adaptive", "minimum": 80 }], "children": [{ "text": { "value": "Tile" } }] } }
```

### `lazyHGrid`

```json
{ "lazyHGrid": { "rows": [{ "size": "fixed", "value": 44 }], "children": [] } }
```

### `group`

Applies modifiers to several views without adding layout.

```json
{ "group": { "children": [{ "text": { "value": "A" } }], "modifiers": [{ "foregroundColor": { "color": "#FF8E8E93" } }] } }
```

### `scrollView`

| Key | |
|---|---|
| `children` | Stacked along the scroll axis |
| `axes` | `"vertical"` (default), `"horizontal"` or `"both"` |
| `showsIndicators` | A bool |

```json
{ "scrollView": { "axes": "horizontal", "showsIndicators": false, "children": [] } }
```

### `spacer`

| Key | |
|---|---|
| `minLength` | A number |

```json
{ "spacer": { "minLength": 16 } }
```

### `divider`

```json
{ "divider": {} }
```

### `geometryReader`

Renders `content` with a read-only `geometry` local (`width`, `height`, `safeArea.top/leading/bottom/trailing`).

| Key | |
|---|---|
| `content` | **required** |
| `name` | The local's name (default `geometry`) |

```json
{ "geometryReader": { "content": { "text": { "value": { "format": ["{0} wide", { "var": "geometry.width" }] } } } } }
```

### Lists and data

### `forEach`

One `content` per element of the array at `items`, with `item` (or `itemName`) and `index` locals.

| Key | |
|---|---|
| `items` | **required.** A state path to an array |
| `content` | **required** |
| `itemName` | Default `item` |
| `identity` | An expression per element (e.g. `{"var": "item.id"}`) that keeps rows stable when the array changes; default: the position |

```json
{ "forEach": { "items": "todos", "itemName": "todo", "identity": { "var": "todo.id" },
               "content": { "toggle": { "isOn": "todo.done", "title": { "var": "todo.title" } } } } }
```

### `list`

Static `children` rows, followed by one row per element of `items` (same keys as `forEach`).

```json
{ "list": { "children": [{ "text": { "value": "Header row" } }], "items": "todos", "content": { "text": { "value": { "var": "item.title" } } } } }
```

### `table`

| Key | |
|---|---|
| `items` | **required.** A state path to an array |
| `columns` | **required.** `[{"title": …, "content": view}]`, each rendered with `item` and `index` |
| `itemName` | |

Multi-column on iOS 17.4 and later; before that, and at compact widths, the first column is shown as a list.

```json
{ "table": { "items": "people", "columns": [
  { "title": "Name", "content": { "text": { "value": { "var": "item.name" } } } },
  { "title": "Email", "content": { "text": { "value": { "var": "item.email" } } } } ] } }
```

### `if`

| Key | |
|---|---|
| `condition` | **required.** A bool expression |
| `then` | **required** |
| `else` | Optional |

```json
{ "if": { "condition": { "gte": [{ "var": "count" }, 10] }, "then": { "text": { "value": "Double digits!" } }, "else": { "text": { "value": "Keep going" } } } }
```

### Controls

### `button`

| Key | |
|---|---|
| `title` or `label` | Text, or a custom view |
| `action` | The actions to run |
| `role` | `"destructive"` or `"cancel"` |

```json
{ "button": { "title": "Delete", "role": "destructive", "action": [{ "set": "deleted", "to": true }] } }
```

### `field`

A text field. `secureField` has the same keys.

| Key | |
|---|---|
| `text` | **required.** A state path |
| `title` | Placeholder text |
| `prompt` | |
| `onSubmit` | Actions to run on Return |

```json
{ "field": { "text": "form.email", "title": "Email", "onSubmit": [{ "call": "signIn" }],
             "modifiers": [{ "keyboardType": { "type": "emailAddress" } }, { "textInputAutocapitalization": { "mode": "never" } }] } }
```

### `secureField`

```json
{ "secureField": { "text": "form.password", "title": "Password" } }
```

### `toggle`

| Key | |
|---|---|
| `isOn` | **required.** A state path holding a bool |
| `title` or `label` | |

```json
{ "toggle": { "isOn": "settings.notifications", "title": "Notifications" } }
```

### `picker`

| Key | |
|---|---|
| `selection` | **required.** A state path |
| `items` | **required.** A state path to the options array |
| `content` | The view for each option (default: the option as text) |
| `value` | The value an option writes to `selection` (default: the option itself) |
| `itemName`, `title`, `label` | |

```json
{ "picker": { "title": "Size", "selection": "order.size", "items": "sizes",
              "content": { "text": { "value": { "var": "item.label" } } }, "value": { "var": "item.id" } } }
```

### `datePicker`

| Key | |
|---|---|
| `selection` | **required.** A state path holding an ISO 8601 date (`null` reads as now) |
| `components` | `["date"]`, `["hourAndMinute"]` or both (default) |
| `minimum`, `maximum` | ISO 8601 dates |
| `title`, `label` | |

```json
{ "datePicker": { "title": "Due", "selection": "task.due", "components": ["date"] } }
```

### `progressView`

Determinate with `value` (and `total`, default 1), a timer with `timerStart`/`timerEnd` (ISO 8601) and `countsDown`, or indeterminate with neither.

| Key | |
|---|---|
| `value`, `total`, `timerStart`, `timerEnd`, `countsDown` | |
| `title`, `label`, `currentValueLabel` | |

```json
{ "progressView": { "title": "Uploading", "value": { "var": "uploaded" }, "total": { "var": "size" } } }
```

### `controlGroup`

| Key | |
|---|---|
| `children` | Usually buttons |
| `label` | |

```json
{ "controlGroup": { "children": [{ "button": { "title": "Bold", "action": [] } }, { "button": { "title": "Italic", "action": [] } }] } }
```

### Containers and navigation

### `form`

```json
{ "form": { "children": [{ "section": { "title": "Account", "children": [{ "field": { "text": "name", "title": "Name" } }] } }] } }
```

### `section`

| Key | |
|---|---|
| `children` | |
| `title`, or `header`/`footer` views | |

```json
{ "section": { "header": { "text": { "value": "Notifications" } }, "footer": { "text": { "value": "You can change this later." } }, "children": [] } }
```

### `navigationStack`

| Key | |
|---|---|
| `root` | **required** |

```json
{ "navigationStack": { "root": { "list": { "children": [] } }, "modifiers": [] } }
```

### `navigationLink`

| Key | |
|---|---|
| `label` | **required** |
| `destination` | **required** |

```json
{ "navigationLink": { "label": { "label": { "title": "Profile", "systemImage": "person" } }, "destination": { "text": { "value": "Profile screen" } } } }
```

### `tab`

Each child is a tab (give it a `tabItem` modifier). Tabs are tagged by position.

| Key | |
|---|---|
| `children` | |
| `selection` | A state path holding the selected tab's index |

```json
{ "tab": { "selection": "selectedTab", "children": [
  { "text": { "value": "Home", "modifiers": [{ "tabItem": { "content": { "label": { "title": "Home", "systemImage": "house" } } } }] } } ] } }
```

### Shapes and color

### `color`

| Key | |
|---|---|
| `color` | **required.** A hex string, `#RRGGBB` or `#AARRGGBB` |

```json
{ "color": { "color": "#FF007AFF", "modifiers": [{ "frame": { "height": 4 } }] } }
```

### `rectangle`

```json
{ "rectangle": { "modifiers": [{ "foregroundColor": { "color": "#FF34C759" } }, { "frame": { "width": 40, "height": 40 } }] } }
```

### `roundedRectangle`

| Key | |
|---|---|
| `cornerRadius`, or `cornerWidth` and `cornerHeight` | |
| `style` | `"circular"` or `"continuous"` |

```json
{ "roundedRectangle": { "cornerRadius": 12, "style": "continuous" } }
```

### `circle`

```json
{ "circle": {} }
```

### `ellipse`

```json
{ "ellipse": { "modifiers": [{ "frame": { "width": 60, "height": 30 } }] } }
```

### `capsule`

| Key | |
|---|---|
| `style` | `"circular"` or `"continuous"` |

```json
{ "capsule": { "style": "circular" } }
```

### Composition

### `ref`

Renders a named view from the payload's `views`.

```json
{ "ref": "footer" }
```

### `custom`

A view the host app registered with `StateStore.components["name"]`. Unregistered names are reported and render nothing.

| Key | |
|---|---|
| `name` | **required** |
| `props` | Expressions, evaluated in the current scope |
| `on` | Event names the view can `send`, mapped to action lists |

```json
{ "custom": { "name": "productCard", "props": { "id": { "var": "item.id" } }, "on": { "select": [{ "set": "selected", "to": { "var": "item.id" } }] } } }
```

### `empty`

Renders nothing.

```json
{ "empty": {} }
```

## Modifiers

Every argument is an expression unless noted; state paths are plain strings. Omitted arguments use SwiftUI's defaults. Unknown modifiers are skipped with a warning; a known modifier with bad arguments rejects the payload.

### Text

| Modifier | Arguments |
|---|---|
| `systemFont` | `font`: a text style (see [Options](#options)) |
| `font` | `name`, `size`: a custom font |
| `systemFontSize` | `size` (**required**), `weight`, `design`: the system font at a size (*schema 1.1*) |
| `fontWeight` | `weight` |
| `fontDesign` | `design`: `default`, `serif`, `rounded`, `monospaced` |
| `fontWidth` | `width`: `compressed`, `condensed`, `standard`, `expanded` |
| `bold`, `italic`, `monospaced` | `isActive` (default true) |
| `monospacedDigit` | none |
| `kerning`, `tracking` | `value` |
| `underline`, `strikethrough` | `isActive`, `pattern` (`solid`, `dot`, `dash`, `dashDot`, `dashDotDot`), `color` |
| `lineLimit` | `limit` (omit for no limit) |
| `truncationMode` | `mode`: `head`, `middle`, `tail` |
| `multilineTextAlignment` | `alignment`: `leading`, `center`, `trailing` |
| `minimumScaleFactor` | `factor` |

```json
[{ "systemFont": { "font": "headline" } }, { "systemFontSize": { "size": 64, "weight": "bold", "design": "rounded" } }, { "fontWeight": { "weight": "semibold" } }, { "underline": { "pattern": "dash", "color": "#FFFF3B30" } }, { "lineLimit": { "limit": 2 } }]
```

### Layout

| Modifier | Arguments |
|---|---|
| `frame` | `width`, `height`, `minWidth`, `idealWidth`, `maxWidth`, `minHeight`, `idealHeight`, `maxHeight` (numbers or `"infinity"`), `alignment` |
| `padding` | `edges` (default `all`), `length` |
| `position` | `x`, `y` |
| `layoutPriority` | `priority` |
| `fixedSize` | `horizontal`, `vertical` (both omitted means both) |
| `ignoresSafeArea` | `edges` |
| `aspectRatio` | `contentMode` (**required**): `fit`, `fill`; `ratio` (width ÷ height, default: the content's own) (*schema 1.1*) |

```json
[{ "padding": { "edges": "horizontal", "length": 16 } }, { "frame": { "maxWidth": "infinity", "alignment": "leading" } }, { "aspectRatio": { "contentMode": "fit" } }]
```

### Appearance

| Modifier | Arguments |
|---|---|
| `foregroundColor` | `color` (hex) |
| `background` | `content`: a view (**required**), `alignment` |
| `cornerRadius` | `radius` |
| `border` | `color`, `width` (default 1) |
| `opacity` | `value` |
| `shadow` | `color`, `radius`, `x`, `y` |
| `blur` | `radius` (**required**), `isOpaque` |
| `brightness` | `amount` |
| `blendMode` | `mode` (see [Options](#options)) |
| `colorInvert` | none |
| `colorMultiply` | `color` |
| `symbolRenderingMode` | `mode`: `monochrome`, `hierarchical`, `multicolor`, `palette` |
| `imageScale` | `scale`: `small`, `medium`, `large` |
| `unredacted` | none |
| `animation` | `animation` (see [Options](#options)), `value`: animates when this changes |

```json
[{ "background": { "content": { "roundedRectangle": { "cornerRadius": 8 } } } }, { "shadow": { "radius": 4, "y": 2 } }, { "opacity": { "value": { "if": [{ "var": "busy" }, 0.5, 1] } } }]
```

### Presentation and navigation

| Modifier | Arguments |
|---|---|
| `sheet` | `isPresented` (state path), `content` (view) |
| `fullScreenCover` | `isPresented`, `content` |
| `popover` | `isPresented`, `content`, `attachmentAnchor`, `arrowEdge` |
| `alert` | `isPresented`, `alert`: `{"title", "message", "buttons": [{"label", "role", "action"}]}` |
| `confirmationDialog` | `isPresented`, `title`, `titleVisibility` (`automatic`, `visible`, `hidden`), `actions` (view) |
| `navigationTitle` | `title` |
| `tabViewStyle` | `style`: `automatic`, `page` (swipe between a `tab`'s children); `indexDisplayMode`: `automatic`, `always`, `never` (page dots) (*schema 1.1*) |
| `indexViewStyle` | `backgroundDisplayMode`: `automatic`, `always`, `never` (a backdrop behind the page dots) (*schema 1.1*) |

```json
[{ "navigationTitle": { "title": "Inbox" } },
 { "tabViewStyle": { "style": "page", "indexDisplayMode": "always" } }, { "indexViewStyle": { "backgroundDisplayMode": "always" } },
 { "alert": { "isPresented": "confirmingDelete", "alert": { "title": "Delete?", "message": "This can't be undone.",
   "buttons": [{ "label": "Delete", "role": "destructive", "action": [{ "call": "deleteSelected" }] }, { "label": "Cancel", "role": "cancel" }] } } }]
```

### Controls and input

| Modifier | Arguments |
|---|---|
| `disabled` | `isDisabled` |
| `buttonStyle` | `style`: `automatic`, `bordered`, `borderedProminent`, `borderless`, `plain` |
| `pickerStyle` | `style`: `automatic`, `inline`, `menu`, `navigationLink`, `segmented`, `wheel` |
| `datePickerStyle` | `style`: `automatic`, `compact`, `graphical`, `wheel` |
| `tag` | `value` |
| `badge` | `value` (a number or text) |
| `tabItem` | `content` (view) |
| `keyboardType` | `type` (see [Options](#options)) |
| `autocorrectionDisabled` | `isDisabled` (default true) |
| `textInputAutocapitalization` | `mode`: `never`, `words`, `sentences`, `characters` |
| `textContentType` | `type` (see [Options](#options)) |

```json
[{ "buttonStyle": { "style": "borderedProminent" } }, { "disabled": { "isDisabled": { "eq": [{ "length": { "var": "draft" } }, 0] } } }]
```

### Events

| Modifier | Arguments |
|---|---|
| `onAppear` | `do`: actions |
| `onDisappear` | `do` |
| `onTapGesture` | `do`, `count` |
| `onChange` | `of`: an expression, `do`: runs when its value changes |
| `onSubmit` | `do` |

```json
[{ "onAppear": { "do": [{ "call": "loadSuggestions" }] } }, { "onChange": { "of": { "var": "query" }, "do": [{ "set": "page", "to": 0 }] } }]
```

### Images and shapes

Applied to `image` and shape components; ignored elsewhere.

| Modifier | Arguments |
|---|---|
| `resizable` | `capInsets` (`{"top", "leading", "bottom", "trailing"}`), `resizingMode`: `stretch`, `tile` |
| `renderingMode` | `mode`: `original`, `template` |
| `antialiased` | `isActive` |
| `path` | `x`, `y`, `width`, `height`: shapes only |

```json
[{ "resizable": {} }, { "renderingMode": { "mode": "template" } }]
```

## Options

String values accepted where an option is expected:

- **Text styles** (`systemFont`): `largeTitle`, `title`, `title2`, `title3`, `headline`, `subheadline`, `callout`, `caption`, `caption2`, `footnote`
- **Font weights:** `ultraLight`, `thin`, `light`, `regular`, `medium`, `semibold`, `bold`, `heavy`, `black`
- **Horizontal alignment** (`vStack`, `lazyVGrid`): `leading`, `center`, `trailing`, `listRowSeparatorLeading`, `listRowSeparatorTrailing`
- **Vertical alignment** (`hStack`, `gridRow`, `lazyHGrid`): `top`, `center`, `bottom`, `firstTextBaseline`, `lastTextBaseline`
- **Alignment** (`zStack`, `frame`, `grid`, `background`): `center`, `leading`, `trailing`, `top`, `bottom`, `topLeading`, `topTrailing`, `bottomLeading`, `bottomTrailing`, plus `centerFirstTextBaseline`, `centerLastTextBaseline`, `leadingFirstTextBaseline`, `leadingLastTextBaseline`, `trailingFirstTextBaseline`, `trailingLastTextBaseline`
- **Edge sets** (`padding`, `ignoresSafeArea`): `all`, `horizontal`, `vertical`, `top`, `bottom`, `leading`, `trailing`
- **Animations:** `default`, `linear`, `easeIn`, `easeOut`, `easeInOut`, `spring`, `bouncy`, `smooth`, `snappy`
- **Blend modes:** `normal`, `multiply`, `screen`, `overlay`, `darken`, `lighten`, `colorDodge`, `colorBurn`, `softLight`, `hardLight`, `difference`, `exclusion`, `hue`, `saturation`, `color`, `luminosity`, `sourceAtop`, `destinationOver`, `destinationOut`, `plusDarker`, `plusLighter`
- **Keyboard types:** `default`, `asciiCapable`, `numbersAndPunctuation`, `URL`, `numberPad`, `phonePad`, `namePhonePad`, `emailAddress`, `decimalPad`, `twitter`, `webSearch`, `asciiCapableNumberPad`
- **Text content types:** `name`, `givenName`, `familyName`, `nickname`, `organizationName`, `jobTitle`, `location`, `fullStreetAddress`, `addressCity`, `addressState`, `postalCode`, `countryName`, `telephoneNumber`, `emailAddress`, `URL`, `creditCardNumber`, `username`, `password`, `newPassword`, `oneTimeCode`, `dateTime`, `flightNumber`

An unrecognized option is reported and that modifier is skipped.
