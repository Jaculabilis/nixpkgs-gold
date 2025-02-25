final: prev: {
  premenv = prev.callPackage ./premenv.nix { };
  lib = prev.lib // {
    gold = import ./lib.nix;
  };
}
