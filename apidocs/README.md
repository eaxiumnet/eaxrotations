# Sylvanas Dev Docs — LLM Corpus

Generated from local mirror in `C:\Botting\sylvanas-dev-docs`.

## Files

- `corpus.jsonl`: retrieval-ready chunks with metadata
- `pages_manifest.jsonl`: one JSON record per page
- `pages/*.md`: cleaned markdown per page

## Stats

- pages: 68
- chunks: 2877

## Suggested usage

1. Load `corpus.jsonl` into your vector store (embed `text`).
2. Keep `id`, `url`, `heading`, `source` as metadata for citation.
3. Use `pages/*.md` for direct long-context prompting.
