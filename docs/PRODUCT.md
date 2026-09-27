# Field LAB product summary

Field LAB is a local-first creative memory for a designer working with AI tools. It stores reusable experience—prompt blocks, learnings, references, recipes, tools, workflows and project context—and makes it available to the designer and compatible agents.

The available app is macOS only. The Mac is the desk for organizing and reusing knowledge. An iPhone app and iCloud sync are not available yet; the app currently stores data locally on the Mac. Field LAB does not generate content, host a chatbot, call third-party AI APIs or manage projects as tasks.

Collect is the first-level area of Field LAB for what the user finds. Images,
URLs, notes and ideas arrive from any source, preserve provenance, become
searchable and can be related to Projects without duplicating the underlying
record. Discovery remains in the source platforms; Field LAB is where things
land, gain context and become reusable.

Core loop: **COLLECT → LAB → LEARN**. Connect and reuse remain outcomes of the same loop, not navigation destinations.

First usable slice:

- SwiftUI macOS app with NavigationSplitView.
- SwiftData local store and a repository shared by UI and MCP.
- CRUD for projects, tools, learnings, notes and prompt blocks.
- Deterministic local search.
- Prompt Deck with Copy Stack.
- Project context packs and Always Remember.
- AI Inbox for agent proposals and Activity audit.
- Local MCP server bound to `127.0.0.1`, protected by a Keychain token.

The primary product surfaces are Collect, Lab and Learn. Dashboard, Inbox,
References, Learnings, Prompt Blocks, Recipes, Prompt Deck, Tools, Flows,
Projects, AI Inbox and Activity are contextual views, filters or Settings
destinations rather than top-level navigation.
