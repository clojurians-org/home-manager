{ config, lib, pkgs, nixos, ... }@nixpkgs:

with lib ;

let
  name = "postgresql" ;
  m = (import <nixpkgs/nixos/modules/services/databases/postgresql.nix> nixpkgs) ;
  sd = m.config.content.systemd.services."${name}" ;
  cfg = config.services.postgresql;
  postgresql =
    if cfg.extraPlugins == []
      then cfg.package
      else cfg.package.withPackages (_: cfg.extraPlugins);
in m // {
  config = { 
    _type = m.config._type; 
    condition = m.config.condition ;
    content = builtins.removeAttrs m.config.content [ "users" "systemd" "meta" ] // {
      environment = {systemPackages = m.config.content.environment.systemPackages; }  ;
      services."${name}" = m.config.content.services."${name}"// {
        superUser = builtins.getEnv "USER" ;
      } ;
      launchd.user.agents."${name}" = {
        serviceConfig.EnvironmentVariables = sd.environment ;
        path = sd.path ++ [ pkgs.coreutils ] ;
        script = builtins.replaceStrings 
                   [ "/run" "chown -R postgres:postgres" ] 
                   [ "/nix/var/run" "#chown -R postgres:postgres" ] ''
          mkdir -p /run
          mkdir -p ${cfg.dataDir}
          ${sd.preStart}
          ${sd.serviceConfig.ExecStart or sd.script}
          # $\{sd.serviceConfig.ExecStartPost}
        '' ;
        serviceConfig.KeepAlive = true;
        serviceConfig.RunAtLoad = true;
      } ;
    }; 
  };
}
