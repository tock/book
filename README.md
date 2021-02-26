Tock Book
=========

Getting started guide for Tock.

[book.tockos.org](https://book.tockos.org/)

This should be generic and expanded as new courses and tutorials are added.



Building the Book
-----------------

Manual steps:

1. `cargo install mdbook --version 0.4.7`
2. `mdbook build`



Deploying the Book
------------------

The book is auto-deployed by Netlify on pushes to the main branch.

Netlify runs:
> `curl -L https://github.com/rust-lang/mdBook/releases/download/v0.4.7/mdbook-v0.4.7-x86_64-unknown-linux-gnu.tar.gz | tar xvz && ./mdbook build`

And published the `book/` directory.
