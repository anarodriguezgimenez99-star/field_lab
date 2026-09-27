# Field LAB product summary

Field LAB is a local-first creative memory for a designer working with AI tools. It stores reusable experience—prompt blocks, learnings, references, recipes, tools, workflows and project context—and makes it available to the designer and compatible agents.

The Mac is the desk for organizing and reusing knowledge; iPhone is the capture-and-consult companion. Both apps share the same private library through optional iCloud sync and remain usable offline. Field LAB does not generate content, host a chatbot, call third-party AI APIs or manage projects as tasks.

Collect is the first-level area of Field LAB for what the user finds. Images,
URLs, notes and ideas arrive from any source, preserve provenance, become
searchable and can be related to Projects without duplicating the underlying
record. Discovery remains in the source platforms; Field LAB is where things
land, gain context and become reusable.

Core loop: **COLLECT → LAB → LEARN**. Connect and reuse remain outcomes of the same loop, not navigation destinations.

First usable slice:

- SwiftUI macOS app with NavigationSplitView and a native iPhone app with Collect, Lab and Learn tabs.
- SwiftData local store and a repository shared by UI and MCP.
- Optional CloudKit sync shared by the signed macOS and iPhone app targets.
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
