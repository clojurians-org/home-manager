{ config, lib, pkgs, nixos, ... }@nixpkgs:

with lib ;

let
  name = "neo4j" ;
  cfg = config.services."${name}" ;
  m = import (<nixpkgs/nixos/modules/services/databases> + builtins.toPath "/${name}.nix") nixpkgs ;
  sd = m.config.content.systemd.services."${name}" ;
  path = (sd.path or []) ++ [ pkgs.coreutils ] ;
  script = builtins.replaceStrings 
             [ "/run" "chown -R neo4j" ] 
             [ "/nix/var/run" "#chown -R neo4j" ] ''
    #! ${pkgs.runtimeShell} -e
    mkdir -p /run
    mkdir -p ${cfg.directories.home}
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
    content = builtins.removeAttrs m.config.content [ "users" "systemd" "meta" ] // 
      optionalAttrs (hasAttrByPath ["services"] m.config.content)  { inherit (m.config.content) services ; } // 
      {
        environment = {systemPackages = m.config.content.environment.systemPackages; }  ;
        
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

      } ;
  };
}
