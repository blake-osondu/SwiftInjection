# Compiling SwiftUI to payloads

Write a screen as ordinary SwiftUI. It builds in Xcode, so Previews work. Then compile it to a payload:

```sh
swift-injection compile Counter.swift --payload-version 42
# Compiled Counter.swift → Counter.json
```

```swift
import SwiftUI

struct Counter: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 8) {
            Text("Tapped \(count) times")
                .font(.title)
            Button("Tap") { count += 1 }
                .buttonStyle(.borderedProminent)
            if count >= 10 {
                Text("Double digits!")
                    .foregroundColor(.green)
            }
        }
        .padding()
    }
}
```

The compiler supports a **strict subset** of Swift. Anything outside it is reported at its location, in the format Xcode and most editors make clickable, and **no payload is written**. It never guesses:

```
Broken.swift:7:9: error: 'List' isn't supported in v1 (supported: Text, Image, Label, Button, …)
Broken.swift:10:10: error: Modifier '.navigationTitle' isn't supported in v1
2 errors; no payload written.
```

Then validate, sign and upload as described in [Publishing](Publishing.md).

## What's supported (v1)

### Files and state
- One `struct …: View` per file. Other types, such as models, are ignored.
- `@State` properties (`private` is fine) with **literal** initial values: numbers, strings, booleans, and arrays or dictionaries of those (`[…] as [String: Any]` for mixed types). Type annotations (`: Double`) are honored.

### Views
| SwiftUI | Notes |
|---|---|
| `Text("…")`, `Text(verbatim:)` | String interpolation becomes a live format: `"Tapped \(count) times"` |
| `Image("name")`, `Image(systemName:)` | |
| `Label("Title", systemImage:)`, `Label("Title", image:)` | |
| `Button("Title") { … }`, `Button { … } label: { … }`, `Button(action:) { … }` | `role: .destructive` / `.cancel` |
| `Color.blue`, `.red.opacity(0.5)`, `Color(red:green:blue:opacity:)` | Converted to hex (see limitations) |
| `Rectangle`, `Circle`, `Ellipse`, `Capsule(style:)`, `RoundedRectangle(cornerRadius:style:)` | |
| `Spacer(minLength:)`, `Divider()`, `EmptyView()` | |
| `VStack`, `HStack`, `ZStack`, `LazyVStack`, `LazyHStack` | `alignment:`, `spacing:` |
| `Group`, `Form`, `Section("Title")` / `Section { } header: { } footer: { }` | |
| `ScrollView(.horizontal, showsIndicators:)`, `NavigationStack` | |
| `if` / `else if` / `else` | Re-evaluated when state changes |

### Modifiers
`font` (text styles like `.title`, and `.custom(_:size:)`), `fontWeight`, `bold`, `italic`, `monospaced`, `monospacedDigit`, `underline`, `strikethrough`, `lineLimit`, `multilineTextAlignment`, `kerning`, `tracking`, `minimumScaleFactor`, `padding`, `frame` (including `.infinity`), `position`, `layoutPriority`, `fixedSize`, `ignoresSafeArea`, `foregroundColor` / `foregroundStyle` / `tint`, `background`, `cornerRadius`, `opacity`, `blur`, `brightness`, `shadow`, `border`, `imageScale`, `resizable`, `renderingMode`, `disabled`, `buttonStyle`, `onAppear`, `onDisappear`, `onTapGesture`.

Arguments can be literals or expressions over state: `.opacity(isBusy ? 0.5 : 1)`, `.disabled(name.isEmpty)`.

### Expressions
Literals, `@State` properties (`count`, `self.count`), `+ - * / %`, `== != < <= > >=`, `&& || !`, ternaries, string interpolation, `String(x)`, `Double(x)`, `.count`, `.isEmpty`, and subscripts (`items[0]`, `user["name"]`).

### Actions
Inside button and gesture closures: assignments (`count = 0`, `user["name"] = "Ada"`), `+= -= *= /=`, `flag.toggle()`, and `if` / `else if` / `else`.

## Limitations

- **Types are inferred, not checked.** SwiftSyntax reads syntax only; there's no type checker. Types come from `@State` initial values, annotations and literals, and they decide things like whether `+` adds numbers or joins strings.
- **No integer division.** `a / b` on two `Int`s is an error, because the runtime's numbers are doubles and would give `3.5` where Swift gives `3`. Make one side a `Double`.
- **Colors become fixed hex values.** `.blue` uses the iOS light-appearance value and doesn't adapt to dark mode. Asset colors and dynamic colors (`.primary`, `.secondary`) aren't supported.
- **Not in v1:** `ForEach` and `List`, inputs (`TextField`, `Toggle`, `Picker`, …), sheets and alerts, helper views, `onChange`, and scripts. These are coming in compiler v2 (#21). Until then, write those parts in JSON, or register a native view as a [custom component](../Sources/SwiftInjection/Custom/CustomComponent.swift).
