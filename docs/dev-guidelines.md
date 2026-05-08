# Fleur de Lys — Developer Guidelines

## File Structure

Every driver lives in its own folder and must have exactly two files:

```
src/drivers/<name>/<name>.h
src/drivers/<name>/<name>.cpp
```

No header-only drivers. No implementation in `.h` files.

## Functions

- `inline` is banned. Define functions in `.cpp`, declare in `.h`.
- Every function must be written with the best achievable Big O complexity. If a faster algorithm exists, use it. No naive loops where a lookup table or bitwise trick applies.
- No unnecessary intermediate variables — pass values directly into calls when the language allows it.

## Examples

Bad:
```cpp
// inline banned
inline int foo(int x) { return x + 1; }

// unnecessary variable
int n = va_arg(args, int);
print_int(n, 10);

// naive digit count — O(log n) with division loop when O(1) lookup exists
int digits = 0;
while (n > 0) { n /= 10; digits++; }
```

Good:
```cpp
// defined in .cpp, declared in .h
int foo(int x);

// direct
print_int(va_arg(args, int), 10);

// O(1) digit count via log2 + lookup table
int digits = log10i(n) + 1;
```
