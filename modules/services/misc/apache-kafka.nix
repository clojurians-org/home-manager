{ config, lib, pkgs, nixos, ... }@nixpkgs:

with lib ;

let
  name = "apache-kafka" ;
  cfg = config.services."${name}" ;
  m = import (<nixpkgs/nixos/modules/services/misc> + builtins.toPath "/${name}.nix") nixpkgs ;
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
          serviceConfig.EnvironmentVariables = mapAttrs (n: v: toString v) (sd.environment or {});
          path = (sd.path or []) ++ [ pkgs.coreutils ] ;
          script = builtins.replaceStrings  
                     [ "/run" ] 
                     [ "/nix/var/run" ] ''
            mkdir -p /run
            ${concatMapStringsSep "\n" (d: "mkdir -p ${d}") cfg.logDirs}

            ${optionalString (hasAttrByPath ["preStart"] sd) sd.preStart}
            ${sd.serviceConfig.ExecStart or sd.script}
            # $\{sd.serviceConfig.ExecStartPost}
          '' ;
          serviceConfig.KeepAlive = true;
          serviceConfig.RunAtLoad = true;
        } ;
      } ;
  };
}
