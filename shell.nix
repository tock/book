# Shell expression for the Nix package manager
#
# This nix expression creates an environment with necessary packages installed:
#
#  * mdBook
#
# To use:
#
#  $ nix-shell

{ pkgs ? import <nixpkgs> {} }:

with builtins;
with pkgs;
stdenv.mkDerivation {
  name = "tock-book";
  buildInputs = [
    mdbook
  ];
}
