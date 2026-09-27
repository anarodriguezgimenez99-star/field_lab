# Field LAB visual system

## Direction

Field LAB is a calm, dark macOS workspace for building a personal creative memory. The interface should feel native to Apple while carrying a subtle nocturnal studio character: quiet chrome, strong hierarchy, system typography, deep surfaces and one clear action at a time.

## Appearance

- Dark mode is the default appearance for the macOS app.
- The canvas and sidebar use near-black violet-gray tones; cards use the supplied `#120F17` surface with restrained translucent borders.
- Off-white carries hierarchy while purple, pink and sky-blue are reserved for the edge-light interaction on cards.
- Keep the chrome quiet. The color appears as a localized response to pointer proximity, never as a full-page gradient or always-on decoration.

## Composition

- `NavigationSplitView` is the primary shell: a compact, labeled sidebar and one focused detail surface.
- The sidebar contains only Collect, Lab and Learn, with Settings separated at the bottom. The labels are plain and scannable.
- Lab is the default surface and uses a clean experiment list/workspace instead of a dashboard grid.
- Empty states explain what belongs in a section and offer one obvious next action.
- Quick Capture opens as a centered modal overlay: the background dims, the panel scales/fades into place, the title field is focused and the action row stays simple.
- Editors remain focused for CRUD work. Context menus remain available for secondary actions on macOS.
- Use cards only where an experiment or visual reference benefits from a preview. In collection views, rely on spacing and typography to create hierarchy.

## Type and spacing

- Use the system SF font and SwiftUI text styles. Display headings may use a rounded system weight, while body copy stays at native readable sizes.
- Headings are compact and confident; supporting copy uses secondary semantic color with sufficient contrast.
- Prefer a 24–32 pt content inset, 16–24 pt section rhythm and 8–12 pt control grouping.

## Interaction

- Quick Capture is the persistent primary action and opens with a short ease-out fade/scale transition.
- The capture flow supports an inline title, description placeholder, compact project/tool context, Create More and a dark primary Save action.
- Search is always close to the current collection.
- Cards use a 28 pt dark surface and a pointer-directed edge glow. The glow is disabled when the pointer leaves the card and does not auto-sweep on load.
- The initial store is empty by design; the first-run experience teaches through concise empty-state copy rather than sample records.
- Respect keyboard shortcuts, focus rings, context menus and reduced-motion/system accessibility settings.

## Preview

`preview.html` is a local, interactive visual reference for the current shell. It is not a second implementation of the application and must not become the source of truth over the SwiftUI code.
