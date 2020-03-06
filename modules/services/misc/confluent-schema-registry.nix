{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.confluent-schema-registry ;

  schemaRegistryProperties =
    if cfg.schemaRegistryProperties != null then
      cfg.schemaRegistryProperties
    else
      ''
        # Generated by nixos
        kafkastore.bootstrap.servers=${concatStringsSep "," cfg.kafkas}
        listeners=${concatStringsSep "," cfg.listeners}
        ${toString cfg.extraProperties}
      '';

  schemaRegistryConfig = pkgs.writeText "schema-registry.properties" schemaRegistryProperties;
  logConfig = pkgs.writeText "log4j.properties" cfg.log4jProperties;

in {

  options.services.confluent-schema-registry = {
    enable = mkOption {
      description = "Whether to enable Apache Kafka.";
      default = false;
      type = types.bool;
    };

    kafkas = mkOption {
      description = "The address the socket server listens on";
      default = [ "PLAINTEXT://127.0.0.1:9092" ];
      type = types.listOf types.str;
    };

    listeners = mkOption {
      description = "The address the socket server listens on";
      default = [ "http://0.0.0.0:8081" ];
      type = types.listOf types.str;
    };


    extraProperties = mkOption {
      description = "Extra properties for schema-registry.properties.";
      type = types.nullOr types.lines;
      default = null;
    };

    schemaRegistryProperties = mkOption {
      description = ''
        Complete schema-registry.properties content. Other schema-registry.properties config
        options will be ignored if this option is used.
      '';
      type = types.nullOr types.lines;
      default = null;
    };

    log4jProperties = mkOption {
      description = "Kafka log4j property configuration.";
      default = ''
        log4j.rootLogger=INFO, stdout
        log4j.appender.stdout=org.apache.log4j.ConsoleAppender
        log4j.appender.stdout.layout=org.apache.log4j.PatternLayout
        log4j.appender.stdout.layout.ConversionPattern=[%d] %p %m (%c)%n
      '';
      type = types.lines;
    };

    jvmOptions = mkOption {
      description = "Extra command line options for the JVM running Kafka.";
      default = [
        "-server"
        "-Xmx1G"
        "-Xms1G"
        "-XX:+UseCompressedOops"
        "-XX:+UseParNewGC"
        "-XX:+UseConcMarkSweepGC"
        "-XX:+CMSClassUnloadingEnabled"
        "-XX:+CMSScavengeBeforeRemark"
        "-XX:+DisableExplicitGC"
        "-Djava.awt.headless=true"
        "-Djava.net.preferIPv4Stack=true"
      ];
      type = types.listOf types.str;
      example = [
        "-Djava.net.preferIPv4Stack=true"
        "-Dcom.sun.management.jmxremote"
        "-Dcom.sun.management.jmxremote.local.only=true"
      ];
    };

    package = mkOption {
      description = "The kafka package to use";
      default = pkgs.confluent-platform ;
      defaultText = "pkgs.confluent-platform";
      type = types.package;
    };

  };

  config = mkIf cfg.enable {

    environment.systemPackages = [cfg.package];

    launchd.user.agents.confluent-schema-registry = 
      let 
        classpath = concatStringsSep ":" 
                      (map (x: "${cfg.package}/share/java/${x}/*")
                        [ "confluent-security/schema-registry" 
                          "confluent-common" 
                          "rest-utils" 
                          "schema-registry"]) ;
      in 
      {
          path = [ cfg.package pkgs.coreutils ];
          script = ''
            # Initialise the database.
            ${pkgs.jre}/bin/java \
              -cp "${classpath}" \
              -Dlog4j.configuration=file:${logConfig} \
              ${toString cfg.jvmOptions} \
              io.confluent.kafka.schemaregistry.rest.SchemaRegistryMain \
              ${schemaRegistryConfig}
          '';
        
          serviceConfig.KeepAlive = true;
          serviceConfig.RunAtLoad = true;
    } ;
  };
}
