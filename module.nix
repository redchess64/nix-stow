{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.nix-stow;
in
  with lib; {
    options.nix-stow = {
      enable = mkEnableOption "nix-stow";
      package = mkPackageOption pkgs "stow" {};
      users = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            enable = mkEnableOption "user";
            package = mkOption {
              type = types.path;
            };
          };
        });
        default = {};
      };
    };

    config = mkIf cfg.enable {
      systemd.services =
        mapAttrs' (
          name: usercfg:
            nameValuePair "nix-stow-${name}" {
              description = "nix-stow for ${name}";

              wantedBy = ["multi-user.target"];

              serviceConfig = {
                User = name;
                Type = "oneshot";
                TimeoutStartSec = "5m";
                SyslogIdentifier = "nix-stow-${name}";

                ExecStart = let
                  home = config.users.users.${name}.home;
                  script =
                    pkgs.writeScript "nix-stow-activate-${name}" /* bash */ ''
                      #!${pkgs.runtimeShell} -el

                      PATH=${cfg.package}/bin:$PATH
                      STATE=''${XDG_STATE_HOME:=${home}/.local/state}/nix-stow

                      [[ -d $STATE ]] || mkdir -p $STATE

                      cd $STATE

                      if ! [[ -e current ]] then
                        ln -sT /var/empty 0
                        ln -sT /var/empty 1
                        ln -sT 1 current
                      fi

                      OLD=$(readlink current)
                      NEW=$(( ! OLD ))

                      if [[ -L current  ]] then
                        ln -sT ${usercfg.package} $NEW -f
                        stow -d ./. -t ${home} -S $NEW -D $OLD
                        ln -sT $NEW current -f
                      else
                        echo "$STATE/current exists and is not a symbolic link"
                        exit 1
                      fi
                    '';
                in "${script}";
              };
            }
        )
        # Only create services for enabled users
        (filterAttrs (_: usercfg: usercfg.enable == true) cfg.users);

      # Fail if any user is disabled or nonexistent but enabled in nix-stow
      assertions = [
        {
          assertion = {} == (filterAttrs (name: usercfg: !config.users.users.${name}.enable or false && usercfg.enable) cfg.users);
          message = "a nix-stow user was enabled and nonexistent";
        }
      ];
    };
  }
