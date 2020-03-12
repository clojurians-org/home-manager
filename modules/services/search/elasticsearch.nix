{ config, lib, pkgs, nixos, ... }@nixpkgs:

with lib ;

let
  name = "elasticsearch" ;
  cfg = config.services."${name}" ;
  m = import (<nixpkgs/nixos/modules/services/search> + builtins.toPath "/${name}.nix") nixpkgs ;
  sd = m.config.content.systemd.services."${name}" ;
  path = (sd.path or []) ++ [ pkgs.coreutils ] ;
  script = builtins.replaceStrings 
             [ "/run" ] 
             [ "/nix/var/run" ] ''
    #! ${pkgs.runtimeShell} -e
    mkdir -p /run
    mkdir -p ${cfg.dataDir}
    rm -rf ${cfg.dataDir}/config
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

      } ;
  };
}
