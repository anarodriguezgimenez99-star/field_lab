# FIELD on iPhone

This document describes the maintained iPhone app source. It is not a public
installation guide: the app and Share Extension have no distributed installer.
CloudKit sync requires Apple-team identifiers, signing, and schema
configuration as described in docs/ICLOUD_SETUP.md.

## Mode

Operate. FIELD on iPhone is for quick capture and reference while away from
the desk; the Mac remains the full organization and experiment workspace.

## Main tasks

- Save an image, URL, or short note into Collect, including from other iPhone
  apps through the system Share menu.
- Open `fieldlab://capture?url=<percent-encoded-URL>` from an integration or
  Shortcut to start a new reference with its URL and suggested title filled in.
- Find and read references, experiments, learnings, recipes, and prompt blocks
  already in the shared FIELD library.
- Add or edit references, learnings, recipes, decisions, styles, notes, prompt
  blocks, experiments, and experiment runs without leaving the current context.
- Organize references by project, attach knowledge and experiments to existing
  projects and tools, and record the model used for recipes and experiments.
- Configure experiment references, prompt blocks, and settings on the phone;
  each new run keeps a snapshot, and prompts can be shared with other apps.
- Record run status, evaluation, observations, and result images, then reuse
  the best run as a recipe or save an experiment conclusion as a learning.
- When CloudKit is configured, keep the same private library available offline
  and synchronize it between signed-in Apple devices.

## Structure

Three native tabs: Recopilar, Laboratorio, and Aprender. Search belongs to the
active tab. Settings stays in each tab's navigation toolbar. Use native lists,
navigation stacks, sheets, system materials, semantic colors, and Dynamic Type.
Follow the iPhone's system appearance so FIELD works in both light and dark
mode.

## Content and states

The library starts empty. Each tab has a concise empty state and a single
capture action. Collect, Lab, and Learn let users switch between active and
archived items so they can restore records from the phone. CloudKit account
availability is visible in Settings. Core capture and reading remain
available offline; sync status explains when iCloud is missing or unavailable.
