# Compiling SwiftUI to payloads

Write a screen as ordinary SwiftUI. It builds in Xcode, so Previews work. Then compile it to a payload:

```sh
swift-injection compile TodoScreen.swift --payload-version 42
# Compiled TodoScreen.swift → TodoScreen.json

swift-injection compile TodoScreen.swift --watch   # recompile on every save
```

```swift
import SwiftUI

struct Todo: Identifiable {
    var id = UUID()
    var title: String
    var done = false
}

struct TodoScreen: View {
    @State private var todos = [Todo(title: "Milk"), Todo(title: "Eggs")]
    @State private var showingHelp = false

    var body: some View {
        NavigationStack {
            List($todos) { $todo in
                TodoRow(todo: $todo)
            }
            .navigationTitle("To-dos")
            .sheet(isPresented: $showingHelp) { Text("Tap a circle to finish a to-do.") }
        }
    }
}

struct TodoRow: View {
    @Binding var todo: Todo

    var body: some View {
        HStack {
            Button { todo.done.toggle() } label: {
                Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
            }
            TextField("To-do", text: $todo.title)
        }
    }
}
```

The compiler supports a **strict subset** of Swift. Anything outside it is reported at its location, in the format Xcode and most editors make clickable, and **no payload is written**. It never guesses:

```
Broken.swift:7:9: error: 'Menu' isn't supported (supported: Text, Image, Label, Button, …)
Broken.swift:10:10: error: Modifier '.toolbar' isn't supported
2 errors; no payload written.
```

Then validate, sign and upload as described in [Publishing](Publishing.md).

The output's `schemaVersion` is the **lowest version the screen needs**: `1.0` unless it uses something newer, such as page-style tab views (schema 1.1). So screens that don't need newer features keep loading in apps built with older versions of SwiftInjection.

## Files

- **The screen** is the `View` named after the file (`TodoScreen.swift` → `TodoScreen`), else the one with `@State`, else the first. Its properties must be `@State`.
- **Model structs** (non-View structs like `Todo`) describe state. Memberwise initializers and field defaults work: `Todo(title: "Milk")` becomes `{"id": "Todo-1", "title": "Milk", "done": false}`. `UUID()` defaults become fixed, reproducible ids. Field types drive type inference (`todo.done` is a `Bool`).
- **Helper views** (other `View` structs):
  - with no properties, they compile once to a named view shared by reference (`{"ref": "Footer"}`);
  - with properties, they're **inlined** at each use with the arguments substituted;
  - `@Binding` properties take `$bindings`, `Color` properties take colors (`tint: .purple`), and defaults (`var punctuation = "!"`) are used when an argument is omitted;
  - helpers can't have `@State`: keep state in the screen and pass it down.

## State

`@State` properties with **literal** initial values: numbers, strings, booleans, arrays and dictionaries of those (`[…] as [String: Any]` for mixed types), and model structs built from literals. `Date()` means "now" (a date picker shows the current date until one is picked). Type annotations (`: Double`, `: [String]`) are honored.

## Views

| SwiftUI | Notes |
|---|---|
| `Text("…")`, `Text(verbatim:)` | Interpolation becomes a live format: `"Tapped \(count) times"` |
| `Image("name")`, `Image(systemName:)`, `Label(_:systemImage:)`, `Label(_:image:)` | |
| `Button("Title") { … }`, `Button { … } label: { … }`, `Button(action:) { … }` | `role: .destructive` / `.cancel` |
| `Color.blue`, `.red.opacity(0.5)`, `Color(red:green:blue:opacity:)` | Converted to hex (see limitations) |
| `Rectangle`, `Circle`, `Ellipse`, `Capsule(style:)`, `RoundedRectangle(cornerRadius:style:)`, `Spacer(minLength:)`, `Divider()`, `EmptyView()` | |
| `VStack`, `HStack`, `ZStack`, `LazyVStack`, `LazyHStack`, `Group`, `Form`, `Section`, `ScrollView` | `alignment:`, `spacing:`, `Section("Title")` or `header:`/`footer:` |
| `NavigationStack`, `NavigationLink("Title") { … }`, `NavigationLink { … } label: { … }` | |
| `TabView`, `TabView(selection: $page)` | Pages are identified by position (`.tag(n)` must match, or leave it off); list pages explicitly rather than with `ForEach` |
| `ForEach(items) { item in … }`, `ForEach($items) { $item in … }`, `ForEach(names, id: \.self) { … }` | Writes through `$item.field` and `item.field = …` reach the real state. Identifiable models are keyed by `id` |
| `List(items) { item in … }`, `List($items) { $item in … }`, `List { … }` | Static rows and `ForEach` can be mixed |
| `TextField(_:text:prompt:)`, `SecureField(_:text:)`, `Toggle(_:isOn:)` | Bound to state with `$name` / `$item.field` |
| `Picker(_:selection:) { ForEach(…) { x in Text(x).tag(x) } }` | Or static options: `Text("Small").tag("s")` |
| `DatePicker(_:selection:displayedComponents:)`, `ProgressView(_:value:total:)` | Dates are stored as ISO 8601 strings |
| `if` / `else if` / `else` | Re-evaluated when state changes |

## Modifiers

- **Text:** `font` (text styles like `.title`, `.system(size:weight:design:)`, or `.custom(_:size:)`), `fontWeight`, `bold`, `italic`, `monospaced`, `monospacedDigit`, `underline`, `strikethrough`, `lineLimit`, `multilineTextAlignment`, `kerning`, `tracking`, `minimumScaleFactor`
- **Layout:** `padding`, `frame` (including `.infinity`), `aspectRatio`, `scaledToFit`, `scaledToFill`, `position`, `layoutPriority`, `fixedSize`, `ignoresSafeArea`
- **Appearance:** `foregroundColor` / `foregroundStyle` / `tint`, `background`, `cornerRadius`, `opacity`, `blur`, `brightness`, `shadow`, `border`, `imageScale`, `resizable`, `renderingMode`, `animation(_:value:)` (presets such as `.easeInOut` or `.spring()`)
- **Controls:** `disabled`, `buttonStyle`, `tag`
- **Navigation and presentation:** `navigationTitle`, `tabItem`, `tabViewStyle(.page(indexDisplayMode:))`, `indexViewStyle(.page(backgroundDisplayMode:))`, `sheet(isPresented:)`, `fullScreenCover(isPresented:)`, `alert(_:isPresented:actions:message:)`, `confirmationDialog(_:isPresented:titleVisibility:actions:)`
- **Events:** `onAppear`, `onDisappear`, `onTapGesture`, `onChange(of:)`, `onSubmit`

Arguments can be literals or expressions over state: `.opacity(isBusy ? 0.5 : 1)`, `.disabled(name.isEmpty)`.

## Expressions and actions

- **Expressions:** literals, `@State` properties, `ForEach` items and their fields, helper parameters, `+ - * / %`, `== != < <= > >=`, `&& || !`, ternaries, string interpolation, `String(x)`, `Double(x)`, `.count`, `.isEmpty`, subscripts (`items[0]`, `user["name"]`).
- **Actions** (button, gesture and event closures): assignments (`count = 0`, `todo.title = ""`), `+= -= *= /=`, `flag.toggle()`, `if` / `else if` / `else`, `runScript(…)` and `hostAction(…)`.

## Scripts

For logic the subset can't express, call JavaScript. Add the `SwiftInjectionAuthoring` library to the target that holds your screens:

```swift
import SwiftInjectionAuthoring

Text(script("formatPrice", price))                       // a String; Previews show ‹formatPrice›
    .opacity(script("fade", progress, placeholder: 1.0))  // another type, with a Preview placeholder
Button("Add") { runScript("addTodo", draft) }             // an action that can change state
```

Define the functions in `<Screen>.scripts.js` next to the screen (or pass `--scripts file.js`):

```js
function formatPrice(amount) { return currency() + amount.toFixed(2) }
function currency() { return "$" }
const addTodo = (title) => { state.set("todos", state.get("todos").concat([{ title }])) }
```

Only the functions the screen calls are included, and each one can use the other functions in the file. Scripts read and write state with `state.get(path)` / `state.set(path, value)`; see `ScriptRuntime` for details and limits.

## Your own components

Enterprise screens are built from the app's design system, not raw SwiftUI. List those views with `--components`, and calls to them compile to `custom` components that the app registers in `StateStore.components`:

```swift
import DesignSystem

BankCard(name: account.name, last4: account.last4, balance: account.balance)
PrimaryButton(title: "Apply") { hostAction("applyForOffer", offer.id) }
```

```sh
swift-injection compile Offers.swift --components BankCard,PrimaryButton,AmountText
# Components the app must register: PrimaryButton
```

Labeled arguments become props (expressions, so they can use state). A trailing closure becomes the `action` event, and labeled closures use their label as the event name. The native view runs them with `context.send("action")`. Screens keep using the real types, so Previews show the real components. `publish-local.sh` reads the list from an optional `screens/components` file.

## Host functions

To call your app's own Swift code (navigation, analytics, feature flags, API calls), use `hostAction` and `hostValue` from `SwiftInjectionAuthoring`:

```swift
Button("View offer") { hostAction("navigate", "offers/" + offer.id) }
if hostValue("featureEnabled", "newOffers", placeholder: false) { OffersBanner() }
```

They compile to the same `call`s as scripts, but need no JavaScript: the app registers them in `StateStore.functions`. `swift-injection compile` lists the host functions each screen expects:

```
Compiled EventScreen.swift → EventScreen.json
Host functions the app must register: submitRSVP
```

## Limitations

- **Types are inferred, not checked.** SwiftSyntax reads syntax only; there's no type checker. Types come from `@State` values, model fields, annotations and literals, and they decide things like whether `+` adds numbers or joins strings.
- **No integer division.** `a / b` on two `Int`s is an error, because the runtime's numbers are doubles and would give `3.5` where Swift gives `3`. Make one side a `Double`.
- **Colors become fixed hex values.** `.blue` uses the iOS light-appearance value and doesn't adapt to dark mode. Asset colors and dynamic colors (`.primary`, `.secondary`) aren't supported.
- **Closures need named parameters** (`{ todo in … }`, not `$0`). `ForEach` iterates `@State` arrays and their fields, not ranges.
- **Not supported yet:** item-based presentation (`.sheet(item:)`), `DatePicker` ranges, `Slider`, `Stepper`, `Menu`, toolbars, environment values, and adding or removing array elements in Swift (use a script). Register a native view as a [custom component](../Sources/SwiftInjection/Custom/CustomComponent.swift) when you need something the subset can't express.
