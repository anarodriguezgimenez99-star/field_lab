# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Stack

Swift 6, SwiftUI y SwiftData. La app macOS es el espacio principal de trabajo; iPhone es el complemento para capturar y consultar. Ambas comparten FieldCore y pueden sincronizar la biblioteca con una base privada de CloudKit. El servidor MCP solo se ejecuta dentro de la app macOS.

## Users

Una diseñadora gráfica / AI Designer que trabaja habitualmente con Claude, Codex, ChatGPT, Krea, Runway, Photoshop, Figma y herramientas similares. Necesita capturar rápidamente descubrimientos y después organizar, conectar y reutilizar su propio conocimiento creativo.

## Product Purpose

Field LAB es una memoria creativa personal, local y estructurada. Guarda aprendizajes, referencias visuales, bloques de prompt, recetas, herramientas, workflows y memoria de proyectos para que vuelvan a ser útiles en trabajos posteriores y puedan ser consultados por agentes de IA.

El éxito inicial consiste en demostrar que una diseñadora puede capturar conocimiento, encontrarlo en macOS, reutilizarlo en un prompt o workflow y compartir contexto fiable con Claude/Codex mediante un servidor MCP local.

## Positioning

Field LAB no genera contenido ni sustituye las herramientas creativas. Su mecanismo diferencial es convertir la experiencia acumulada de una diseñadora en una memoria estructurada y compartida entre ella y sus agentes de IA, con escritura permanente bajo aprobación humana.

## Operating Context

macOS es la superficie de trabajo: organizar biblioteca, referencias, prompts, workflows, proyectos y conexión MCP. iPhone ofrece captura y consulta rápida en las mismas tres áreas. El ciclo de uso es COLLECT → LAB → LEARN; conectar y reutilizar son resultados del ciclo, no destinos de navegación.

La entrega incluye una vertical slice macOS con Collect, Lab, Learn, búsqueda, contexto y MCP local, junto a la app nativa de iPhone para esas tres áreas. Ambas usan el mismo esquema SwiftData; iCloud sincroniza opcionalmente los datos entre dispositivos.

Collect es la superficie de primer nivel para **lo que encuentro**: una
biblioteca visual local donde imágenes, URLs, notas e ideas conservan su origen,
contexto y relaciones para poder encontrarse y reutilizarse más tarde.

## Capabilities and Constraints

- La lógica de dominio vive en FieldCore y se comparte entre macOS y iPhone.
- MCP forma parte de la primera versión usable. Debe ser local-only, enlazado a `127.0.0.1`, protegido con token y con lectura libre pero escritura permanente mediante propuestas aprobables.
- V1 debe cubrir como mínimo: CRUD de proyectos, herramientas, learnings, notes y prompt blocks; búsqueda local determinista; Prompt Deck con Copy Stack; contexto de proyecto; AI Inbox; Activity; y las herramientas MCP esenciales.
- Objetos conceptuales del producto: Tool, Learning, Reference, Block/PromptBlock, Style, Recipe, Experiment, Flow, Project, Session, AgentProposal y AgentActivity. Los que no entren en la vertical slice se incorporarán progresivamente.
- Field LAB no debe incorporar chatbot, generación de imágenes/vídeo/texto, APIs de terceros de IA, CRM, tareas, calendario, colaboración multiusuario, analytics, billing, embeddings ni vector database.
- La persistencia debe funcionar offline y sin cuenta Field LAB. iCloud/CloudKit será opcional y deberá estar documentado, no asumido durante el desarrollo local.
- La UI debe ser nativa Apple, accesible y compatible con modo claro/oscuro; macOS debe favorecer teclado, sidebar, búsqueda, menú contextual y densidad editorial legible.
- Los targets nativos viven en `Apps/FIELD.xcodeproj` y requieren el Xcode completo. La configuración CloudKit incluida usa identificadores de ejemplo y necesita los identificadores del equipo antes de sincronizar datos reales.

## Brand Commitments

El nombre del producto es Field LAB. La frase de producto es “Your creative memory, shared with your AI tools.” / “Tu memoria creativa, compartida con las herramientas de IA con las que trabajas.” La experiencia debe sentirse personal, profesional, calmada, editorial y nativa de Apple, sin parecer un dashboard SaaS genérico.

## Evidence on Hand

Existe una definición funcional extensa proporcionada por la usuaria en los archivos adjuntos de la conversación. El repositorio contiene ahora la app de macOS y su complemento nativo de iPhone, incluido el flujo de referencias, experimentos y aprendizaje. Los identificadores Apple de CloudKit y App Group siguen siendo marcadores; no hay datos de muestra en producción.

## Product Principles

1. Guardar debe ser rápido; organizar puede esperar.
2. Todo lo guardado debe poder encontrarse, conectarse y reutilizarse.
3. La memoria canónica requiere control humano.
4. La misma capa de dominio sirve a la UI y a los agentes MCP.
5. Field LAB conserva el conocimiento propio de la diseñadora, no conocimiento genérico de Internet.

## Accessibility & Inclusion

Usar componentes y navegación nativos de Apple, Dynamic Type donde corresponda, etiquetas accesibles, contraste suficiente, navegación por teclado en macOS, targets táctiles adecuados en iPhone y soporte para modo claro/oscuro y Reduce Motion.
