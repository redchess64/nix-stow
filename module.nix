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

                      if [[ -L $STATE/current ]]; then
                        OLD=$(realpath $STATE/current)
                        [[ $OLD -ef ${usercfg.package} ]] && exit 0
                        stow --no-folding -d $(dirname $OLD) -D $(basename $OLD) -S $(basename ${usercfg.package}) -t ${home}
                        ln -sT ${usercfg.package} $STATE/current -f

                      elif [ -e $STATE/current ]; then
                        echo "$STATE/current exists and is not a symlink"
                        exit 1
                      else
                        stow --no-folding -d $(dirname ${usercfg.package}) $(basename ${usercfg.package}) -t ${home}
                        ln -sT ${usercfg.package} $STATE/current
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
