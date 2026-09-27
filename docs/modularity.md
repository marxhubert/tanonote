# Incremental modularity

Note, Folder, Task and Project share `ContentEntity`, `EntitySorting`, category
normalization and nullable `copyWith` semantics: omission preserves, explicit null
clears. Existing `EntityCard`, slivers, selection and dialogs should remain shared.
Separate repository interfaces preserve business-specific invariants.

Commands repeated across screens — metadata updates, move, trash, restore and
locking — must check authorization, validate invariants, persist, then notify.
Failed writes preserve the previous state and allow retry. Introduce abstractions
together with real callers and meaningful tests.

Keep rich text, task checklist rows, project columns/order and folder membership
explicit. Do not replace typed entities with a generic JSON table solely to remove
similar methods.

Task lists reuse the note document lifecycle with a persisted kind discriminator;
the editor specializes only its content area. See [Task lists](tasks.md).
