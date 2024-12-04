# Zig UUIDv4 Library
A small, self-contained Zig library that generates RFC 4122 Version 4 (random) UUIDs quickly and without allocations. It provides:
* Zero-allocation UUID generation.
* Simple parsing and formatting functions (to and from string).
* Straightforward integration into your Zig projects.

This library is designed to be as minimal and featureless as possible, providing only what you need for UUIDv4 generation according to RFC 4122.

## Features
* Version 4 UUID Generation: Uses std.crypto.random to reliably produce random UUIDs.
* No Allocations: The library does not allocate. It uses fixed-size buffers to store and manipulate UUIDs.
* Parsing & Formatting: Convert a UUID to its canonical string form (e.g. xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx) or parse such a string back into a UUID.

## License
MIT – Feel free to use, modify, and distribute this library as per the terms of the license.

## Contributing
Contributions, bug reports, and feature requests are welcome. Please open an issue or submit a pull request on GitHub.

