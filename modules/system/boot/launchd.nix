{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.system;

  text = import ../../lib/write-text.nix {
    inherit lib;
    mkTextDerivation = pkgs.writeText;
  };

  launchdVariables = mapAttrsToList (name: value: ''
    launchctl setenv ${name} '${value}'
  '');

  userLaunchdActivation = target: ''
    if ! diff ${cfg.build.launchd}/user/Library/LaunchAgents/${target} ~/Library/LaunchAgents/${target} &> /dev/null; then
      if test -f ~/Library/LaunchAgents/${target}; then
        echo "reloading user service $(basename ${target} .plist)" >&2
        launchctl unload ~/Library/LaunchAgents/${target} || true
      else
        echo "creating user service $(basename ${target} .plist)" >&2
      fi
      if test -L ~/Library/LaunchAgents/${target}; then
        rm ~/Library/LaunchAgents/${target}
      fi
      cp -f '${cfg.build.launchd}/user/Library/LaunchAgents/${target}' ~/Library/LaunchAgents/${target}
      launchctl load -w ~/Library/LaunchAgents/${target}
    fi
  '';

  userLaunchAgents = filter (f: f.enable) (attrValues config.environment.userLaunchAgents);

in

{
  options = {
    environment.userLaunchAgents = mkOption {
      type = types.loaOf (types.submodule text);
      default = {};
      description = ''
        Set of files that have to be linked in <filename>~/Library/LaunchAgents</filename>.
      '';
    };

  };

  config = {

    system.build.launchd = pkgs.runCommandNoCC "launchd"
      { preferLocalBuild = true; }
      ''
        mkdir -p $out/user/Library/LaunchAgents
        cd $out/user/Library/LaunchAgents
        ${concatMapStringsSep "\n" (attr: "ln -s '${attr.source}' '${attr.target}'") userLaunchAgents}
      '';

    system.activationScripts.userLaunchd.text = ''
      # Set up user launchd services in ~/Library/LaunchAgents
      echo "setting up user launchd services..."
      ${concatStringsSep "\n" (launchdVariables config.launchd.user.envVariables)}
      ${optionalString (builtins.length userLaunchAgents > 0) ''
      mkdir -p ~/Library/LaunchAgents
      ''}
      ${concatMapStringsSep "\n" (attr: userLaunchdActivation attr.target) userLaunchAgents}
      for f in $(ls ~/Library/LaunchAgents 2> /dev/null | grep org.nixos ); do
        if test ! -e "${cfg.build.launchd}/user/Library/LaunchAgents/$f"; then
          echo "removing user service $(basename $f .plist)" >&2
          launchctl unload ~/Library/LaunchAgents/$f || true
          if test -e ~/Library/LaunchAgents/$f; then rm -f ~/Library/LaunchAgents/$f; fi
        fi
      done
    '';

  };
}
