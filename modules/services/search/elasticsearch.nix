{ config, lib, pkgs, nixos, ... }@nixpkgs:

with lib ;

let
  name = "elasticsearch" ;
  cfg = config.services."${name}" ;
  m = import (<nixpkgs/nixos/modules/services/search> + builtins.toPath "/${name}.nix") nixpkgs ;
  sd = m.config.content.systemd.services."${name}" ;
in m // {
  config = { 
    _type = m.config._type; 
    condition = m.config.condition ;
    content = builtins.removeAttrs m.config.content [ "users" "systemd" "meta" ] // 
      optionalAttrs (hasAttrByPath ["services"] m.config.content)  { inherit (m.config.content) services ; } // 
      {
        environment = {systemPackages = m.config.content.environment.systemPackages; }  ;
        
        launchd.user.agents."${name}" = {
          serviceConfig.EnvironmentVariables = sd.environment ;
          path = (sd.path or []) ++ [ pkgs.coreutils ] ;
          script = builtins.replaceStrings 
                     [ "/run" ] 
                     [ "/nix/var/run" ] ''
            mkdir -p /run
            mkdir -p ${cfg.dataDir}
            ${sd.preStart}
            ${sd.serviceConfig.ExecStart or sd.script}
            # $\{sd.serviceConfig.ExecStartPost}
          '' ;
          serviceConfig.KeepAlive = true;
          serviceConfig.RunAtLoad = true;
        } ;
      } ;
  };
}
