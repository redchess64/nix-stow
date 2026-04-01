{
  nixosModules = rec {
    nix-stow = ./module.nix;
    default = nix-stow;
  };
  checks.x86_64-linux.default = import ./tests { system = "x86_64-linux"; };
}
