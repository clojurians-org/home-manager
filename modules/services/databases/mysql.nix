{ config, lib, pkgs, nixos, ... }@nixpkgs:

with lib ;

let
  name = "mysql" ;
  m = (import <nixpkgs/nixos/modules/services/databases/mysql.nix> nixpkgs) ;
  sd = m.config.content.systemd.services."${name}" ;
in m // {
  config = { 
    _type = m.config._type; 
    condition = m.config.condition ;
    content = builtins.removeAttrs m.config.content [ "users" "systemd" ] // {
      services."${name}".user = builtins.getEnv "USER" ;
      environment.etc."my.cnf".text = ''
        ${m.config.content.environment.etc."my.cnf".text}
        socket =/nix/var/run/mysqld/mysqld.sock
      '' ;
      launchd.user.agents."${name}" = {
        path = sd.path ++ [ pkgs.coreutils ] ;
        script = builtins.replaceStrings ["/run"] ["/nix/var/run"] ''
          mkdir -p /run
          mkdir -p /run/mysqld
          ${sd.preStart}
          ${sd.serviceConfig.ExecStart}
          # $\{sd.serviceConfig.ExecStartPost}
        '' ;
        serviceConfig.KeepAlive = true;
        serviceConfig.RunAtLoad = true;
      } ;
    }; 
  };
}

