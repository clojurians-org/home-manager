{ config, lib, pkgs, ... }:

with lib;

let

  inherit (pkgs) stdenv;

  cfg = config.system;

  script = import ../../lib/write-text.nix {
    inherit lib;
    mkTextDerivation = name: text: pkgs.writeScript "activate-${name}" text;
  };

in

{
  options = {

    system.activationScripts = mkOption {
      internal = true;
      type = types.attrsOf (types.submodule script);
      default = {};
      description = ''
        A set of shell script fragments that are executed when a NixOS
        system configuration is activated.  Examples are updating
        /etc, creating accounts, and so on.  Since these are executed
        every time you boot the system or run
        <command>nixos-rebuild</command>, it's important that they are
        idempotent and fast.
      '';
    };

  };

  config = {

    system.activationScripts.userScript.text = ''
      #! ${stdenv.shell}
      set -e
      set -o pipefail
      export PATH=${pkgs.coreutils}/bin:@out@/sw/bin:${config.environment.systemPath}
      systemConfig=@out@
      _status=0
      trap "_status=1" ERR
      # Ensure a consistent umask.
      umask 0022
      ${cfg.activationScripts.preUserActivation.text}
      # $\{cfg.activationScripts.checks.text}
      ${cfg.activationScripts.extraUserActivation.text}
      # $\{cfg.activationScripts.userDefaults.text}
      ${optionalString pkgs.stdenv.isDarwin cfg.activationScripts.userLaunchd.text}
      ${cfg.activationScripts.postUserActivation.text}
      exit $_status
    '';

    # Extra activation scripts, that can be customized by users
    # don't use this unless you know what you are doing.
    system.activationScripts.extraActivation.text = mkDefault "";
    system.activationScripts.preActivation.text = mkDefault "";
    system.activationScripts.postActivation.text = mkDefault "";
    system.activationScripts.extraUserActivation.text = mkDefault "";
    system.activationScripts.preUserActivation.text = mkDefault "";
    system.activationScripts.postUserActivation.text = mkDefault "";

  };
}
