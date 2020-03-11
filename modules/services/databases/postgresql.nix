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
  path = sd.path ++ [ pkgs.coreutils ] ;
  script = builtins.replaceStrings 
    [ "/run" "chown -R postgres:postgres" "initdb -U" "exec postgres" ] 
    [ "/nix/var/run" "#chown -R postgres:postgres" "initdb -E 'UTF-8' --no-locale -U" 
      "exec postgres -k /nix/var/run"] ''
    #! ${pkgs.runtimeShell} -e
    mkdir -p /run
    mkdir -p ${cfg.dataDir}
    ${sd.preStart}
    ${sd.serviceConfig.ExecStart or sd.script}
    # $\{sd.serviceConfig.ExecStartPost}
  '' ;
  scriptFile = pkgs.writeTextFile {
    name = "${name}-start" ;
    executable = true ;
    text = script ;
  }  ;

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
        inherit path script ;
        serviceConfig.EnvironmentVariables = sd.environment ;
        serviceConfig.KeepAlive = true;
        serviceConfig.RunAtLoad = true;
      } ;
      systemd.user.services."${name}" = {
        Unit = {
          Description = "${name}" ;
        } ;
        Service = {
          Environment = concatStringsSep " " (
            mapAttrsToList (name: value: "${name}=${value}") 
              (sd.environment // { PATH = makeBinPath path ; })
          );
          ExecStart = "${scriptFile}" ;
          RestartSec = 3 ;
          Restart = "always" ;
        } ;
        Install = {
          WantedBy = [ "default.target" ] ;
        } ;
      } ;
    }; 
  };
}
