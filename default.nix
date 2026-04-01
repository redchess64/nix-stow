{
  nixosModules = rec {
    nix-stow = ./module.nix;
    default = nix-stow;
  };
}
