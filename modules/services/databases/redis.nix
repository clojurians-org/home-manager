{ config, lib, pkgs, nixos, ... }@nixpkgs:

with lib ;

let
  name = "redis" ;
  cfg = config.services."${name}" ;
  m = import (<nixpkgs/nixos/modules/services/databases> + builtins.toPath "/${name}.nix") nixpkgs ;
  sd = m.config.content.systemd.services."${name}" ;

  # redis dir and pidfile to user directory
  redisBool = b: if b then "yes" else "no";
  condOption = name: value: if value != null then "${name} ${toString value}" else "";
  conf = "redis.conf" ;
  conf-text = ''
    port ${toString cfg.port}
    ${condOption "bind" cfg.bind}
    ${condOption "unixsocket" cfg.unixSocket}
    # daemonize yes
    # supervised systemd
    loglevel ${cfg.logLevel}
    logfile ${cfg.logfile}
    syslog-enabled ${redisBool cfg.syslog}
    pidfile /run/redis.pid
    databases ${toString cfg.databases}
    ${concatMapStrings (d: "save ${toString (builtins.elemAt d 0)} ${toString (builtins.elemAt d 1)}\n") cfg.save}
    dbfilename dump.rdb
    dir ${cfg.dataDir}
    ${if cfg.slaveOf != null then "slaveof ${cfg.slaveOf.ip} ${toString cfg.slaveOf.port}" else ""}
    ${condOption "masterauth" cfg.masterAuth}
    ${condOption "requirepass" cfg.requirePass}
    appendOnly ${redisBool cfg.appendOnly}
    appendfsync ${cfg.appendFsync}
    slowlog-log-slower-than ${toString cfg.slowLogLogSlowerThan}
    slowlog-max-len ${toString cfg.slowLogMaxLen}
    ${cfg.extraConfig}
  '';

  path = (sd.path or []) ++ [ pkgs.coreutils ] ;
  script = builtins.replaceStrings  
             [ "/run" "/etc"] 
             [ "/nix/var/run"  "/nix/var/etc"] ''
    #! ${pkgs.runtimeShell} -e
    mkdir -p /run
    mkdir -p /etc
    mkdir -p ${cfg.dataDir}
    ${optionalString (hasAttrByPath ["preStart"] sd) sd.preStart}

    echo "${conf-text}" > /etc/redis.conf
    ${cfg.package}/bin/redis-server /etc/redis.conf
    # $\{sd.serviceConfig.ExecStart or sd.script}
    # $\{sd.serviceConfig.ExecStartPost}
  '' ;
  scriptFile = pkgs.writeTextFile {
    name = "${name}-start" ;
    executable = true ;
    text = script ;
  }  ;

  environmentVariables = mapAttrs (n: v: toString v) (sd.environment or {}) ;

in m // {
  options = m.options //
  { services."${name}" = m.options.services."${name}" //
    {
      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/redis";
        description = "Data directory for the redis database.";
      };

    };
  } ;
  config = { 
    _type = m.config._type; 
    condition = m.config.condition ;
    content = builtins.removeAttrs m.config.content [ "users" "systemd" "meta" "networking" "boot" ] // 
      optionalAttrs (hasAttrByPath ["services" name] m.config.content)  { 
        services."${name}" = m.config.content.services."${name}" // 
          optionalAttrs (hasAttrByPath ["services" name "unixSocket"]  m.config.content.services."${name}".unixSocket) 
            { unixSocket = "/nix/var/run/${name}.sock" ;} ; 
      } // 
      {
        environment = {systemPackages = m.config.content.environment.systemPackages; }  ;
         
        launchd.user.agents."${name}" = {
          serviceConfig.EnvironmentVariables = environmentVariables ;
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
                (environmentVariables // { PATH = makeBinPath path ; })
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
