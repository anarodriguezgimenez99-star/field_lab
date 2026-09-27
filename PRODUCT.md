# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Stack

Swift 6, SwiftUI y SwiftData; macOS-first con una futura superficie iPhone/iOS. Persistencia local-first preparada para CloudKit/iCloud. El servidor MCP se ejecutará dentro de la app macOS mediante el SDK oficial de MCP para Swift cuando sea viable.

## Users

Profesionales creativos que trabajan con herramientas de diseño e IA y necesitan capturar descubrimientos, organizarlos y reutilizar conocimiento de proyectos posteriores.

## Product Purpose

Field LAB es una memoria creativa personal, local y estructurada. Guarda aprendizajes, referencias visuales, bloques de prompt, recetas, herramientas, workflows y memoria de proyectos para que vuelvan a ser útiles en trabajos posteriores y puedan ser consultados por agentes de IA.

El éxito inicial consiste en demostrar que una persona creativa puede capturar conocimiento, encontrarlo en macOS, reutilizarlo en un prompt o workflow y compartir contexto fiable con agentes mediante un servidor MCP local.

## Positioning

Field LAB no genera contenido ni sustituye las herramientas creativas. Su mecanismo diferencial es convertir la experiencia acumulada de una persona creativa en una memoria estructurada y compartida con sus agentes de IA, con escritura permanente bajo aprobación humana.

## Operating Context

macOS es la primera superficie de trabajo: organizar biblioteca, referencias, prompts, workflows, proyectos y conexión MCP. iPhone será posteriormente la superficie de captura y consulta rápida. El ciclo de uso es COLLECT → LAB → LEARN; conectar y reutilizar son resultados del ciclo, no destinos de navegación.

La primera entrega debe ser una vertical slice macOS funcional que incluya Collect, Lab, Learn, búsqueda, contexto y MCP local sin convertir esas capacidades en una colección de secciones principales.

Collect es la superficie de primer nivel para **lo que encuentro**: una
biblioteca visual local donde imágenes, URLs, notas e ideas conservan su origen,
contexto y relaciones para poder encontrarse y reutilizarse más tarde.

## Capabilities and Constraints

- La primera implementación prioriza macOS; el modelo y los servicios deben poder extenderse a iPhone sin duplicar la lógica de dominio.
- MCP forma parte de la primera versión usable. Debe ser local-only, enlazado a `127.0.0.1`, protegido con token y con lectura libre pero escritura permanente mediante propuestas aprobables.
- V1 debe cubrir como mínimo: CRUD de proyectos, herramientas, learnings, notes y prompt blocks; búsqueda local determinista; Prompt Deck con Copy Stack; contexto de proyecto; AI Inbox; Activity; y las herramientas MCP esenciales.
- Objetos conceptuales del producto: Tool, Learning, Reference, Block/PromptBlock, Style, Recipe, Experiment, Flow, Project, Session, AgentProposal y AgentActivity. Los que no entren en la vertical slice se incorporarán progresivamente.
- Field LAB no debe incorporar chatbot, generación de imágenes/vídeo/texto, APIs de terceros de IA, CRM, tareas, calendario, colaboración multiusuario, analytics, billing, embeddings ni vector database.
- La persistencia debe funcionar offline y sin cuenta Field LAB. iCloud/CloudKit será opcional y deberá estar documentado, no asumido durante el desarrollo local.
- La UI debe ser nativa Apple, accesible y compatible con modo claro/oscuro; macOS debe favorecer teclado, sidebar, búsqueda, menú contextual y densidad editorial legible.
- Para compilar el target macOS se requiere un toolchain completo de Xcode.

## Brand Commitments

El nombre del producto es Field LAB. La frase de producto es “Your creative memory, shared with your AI tools.” / “Tu memoria creativa, compartida con las herramientas de IA con las que trabajas.” La experiencia debe sentirse personal, profesional, calmada, editorial y nativa de Apple, sin parecer un dashboard SaaS genérico.

## Sample Data

Las instalaciones nuevas empiezan vacías. Cualquier dato incluido para demostraciones o capturas debe ser sintético, estar identificado como ejemplo y mantenerse fuera de los datos de producción.

## Product Principles

1. Guardar debe ser rápido; organizar puede esperar.
2. Todo lo guardado debe poder encontrarse, conectarse y reutilizarse.
3. La memoria canónica requiere control humano.
4. La misma capa de dominio sirve a la UI y a los agentes MCP.
5. Field LAB conserva el conocimiento propio de cada profesional creativo, no conocimiento genérico de Internet.

## Accessibility & Inclusion

Usar componentes y navegación nativos de Apple, Dynamic Type donde corresponda, etiquetas accesibles, contraste suficiente, navegación por teclado en macOS, targets táctiles adecuados en iPhone y soporte para modo claro/oscuro y Reduce Motion.
