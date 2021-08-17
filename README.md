# Tock Book

Getting started guide for Tock.

[book.tockos.org](https://book.tockos.org/)

This should be generic and expanded as new courses and tutorials are added.

## Building the Book

Manual steps:

1. `cargo install mdbook --version 0.4.7`
2. `mdbook build`

### Formatting the book

Manual steps:

1. `npm i -g prettier@2.3.2`
2. `prettier --write --prose-wrap always '**/*.md'`

## Deploying the Book

The book is auto-deployed by Netlify on pushes to the main branch.

If you update mdbook version, you must also update `netlify.toml`.
