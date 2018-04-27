{ pkgs ? import (builtins.fetchTarball https://nixos.org/channels/nixpkgs-17.09-darwin/nixexprs.tar.xz) {} }:

let
  ghc = pkgs.haskellPackages.ghcWithPackages (ps: [ ps.turtle ]);
in
  pkgs.stdenv.mkDerivation {
    name = "deploy-nix-darwin";
    buildInputs = [ ghc ];
    shellHook = "eval $(egrep ^export ${ghc}/bin/ghc)";
    src = ./.;
    buildCommand = ''
      mkdir -p $out/bin
      cp -R "$src/"* $out
      ghc -o $out/bin/deploy $out/deploy.hs
    '';
  }
