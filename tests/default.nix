{pkgs ? import <nixpkgs> {}}:
pkgs.testers.runNixOSTest {
  name = "nix-stow-test";
  nodes.machine = {...}: {
    imports = [../src];
    users.users.test = {
      isNormalUser = true;
    };
    nix-stow = {
      enable = true;
      users = {
        test = {
          enable = true;
          package = ./package;
        };
        fakeperson = {
          enable = false;
          package = ./package;
        };
      };
    };
  };
  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("[ -f /home/test/file ]")
    machine.succeed("[ -f /home/test/directory/nested_directory/nested_file ]")
  '';
}
