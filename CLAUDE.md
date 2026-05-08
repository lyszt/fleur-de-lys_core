# Fleur de Lys — Claude Guidelines

See full dev guidelines: `docs/dev-guidelines.md`

## Rules

- Every driver gets its own folder with a `.h` and `.cpp` file. No exceptions.
- `inline` functions are banned.
- All functions must target the best possible Big O complexity. If a more efficient algorithm exists, use it.
- No unnecessary intermediate variables — pass values directly when possible.
