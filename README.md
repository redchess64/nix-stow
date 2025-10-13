# nix-stow
A nixos module for installing a single stow package into any number of users homes.

Do not use this software unless you have personally verified its functionality.

## Usage
```nix
nix-stow = {
  enable = true;
  users = {
    yourname = {
      enable = true;
      package = ./configs;
    };
  };
};
```

