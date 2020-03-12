{ config, lib, pkgs, nixos, ... }@nixpkgs:

with lib ;

let
  name = "mysql" ;
  cfg = config.services."${name}" ;
  m = import (<nixpkgs/nixos/modules/services/databases> + builtins.toPath "/${name}.nix") nixpkgs ;
  sd = m.config.content.systemd.services."${name}" ;
  path = sd.path ++ [ pkgs.coreutils ] ;
  conf = "my.cnf" ;
  conf-text  = ''
    ${m.config.content.environment.etc."${conf}".text}
    socket = /run/mysqld.sock
  '' ;
  script = builtins.replaceStrings ["/run" "/etc"] ["/nix/var/run" "/nix/var/etc"] ''
    #! ${pkgs.runtimeShell} -e
    mkdir -p /run
    mkdir -p /etc
    echo "${conf-text}" > /etc/${conf}
    mkdir -p ${cfg.dataDir}
    ${sd.preStart}
    ${sd.serviceConfig.ExecStart}
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
    content = builtins.removeAttrs m.config.content [ "users" "systemd" ] // {
      services."${name}".user = builtins.getEnv "USER" ;

      environment = {systemPackages = m.config.content.environment.systemPackages; }  ;

      launchd.user.agents."${name}" = {
        inherit path script ;
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
              ((sd.environment or {})// { PATH = makeBinPath path ; })
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

