# Roadmap

## Navigation simplification

The product surface is now organized around COLLECT → LAB → LEARN.

- Collect is the visual library and low-friction capture surface.
- Lab is the experiment workspace, including ordered Runs, comparison and conclusions.
- Learn is the reusable library for Learnings, Recipes and Prompt Blocks.
- Tools and Projects remain context metadata; MCP and Activity live under Settings.

The existing domain and MCP capabilities remain in place. Future roadmap work
should add depth inside these surfaces rather than adding new top-level sections.

## V1 — macOS vertical slice

Persistence, projects, tools, learnings, notes, prompt blocks, references, search, Prompt Deck, editable workflows, project context, AI Inbox, Activity, MCP, Keychain token and core/integration tests. New stores start empty; sample data remains a developer-only repository helper.

References V1 is the local-first vertical slice: dedicated model, source
resolver, image/URL/note import, visual grid, source/pinned/unclassified filters,
manual tags and attributes, Project relationships, global search and compact
MCP tools.

## V1.1 — local reference intelligence and capture surfaces

OCR, dominant colors, orientation/dimensions, background analysis, duplicate and
feature-print similarity, Smart Collections UI, classification workflow,
Menu Bar quick copy improvements, pinned items and Core Spotlight.

## V1.2 — depth and portability

Production schema promotion, richer experiment attachments, styles, sessions
UI, Rediscover, Shuffle and Markdown/JSON export remain follow-up work.

## Future — iPhone companion

The repository contains maintained iPhone app and Share Extension targets,
plus CloudKit sync support that requires team configuration.
Finishing account configuration, testing sync and preparing the companion for
distribution are future work; the current release is macOS-only and stores data
locally.

## Explicit non-goals

No chatbot, image/video generation, third-party AI API integrations, task manager, CRM, billing, analytics, collaboration or vector database.
