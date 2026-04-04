# Building the iphlpapi wrapper DLL

A pre-built DLL is included (`iphlpapi.dll`). You only need to rebuild if you
want to modify the source.

## Requirements

```bash
brew install mingw-w64
```

## Build

```bash
x86_64-w64-mingw32-gcc -shared -o iphlpapi.dll iphlpapi.c iphlpapi.def -liphlpapi -static-libgcc
```
