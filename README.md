安装过程
------------


1.  安装nix 并配置channel

    
    ```console
    $ sudo install -d -m755 -o $(id -u) -g $(id -g) /nix
    $ curl https://nixos.org/nix/install | sh
    $ source ~/.nix-profile/etc/profile.d/nix.sh

    $ nix-channel --add https://nixos.org/channels/nixos-20.03 nixos-20.03
    $ nix-channel --update nixos-20.03

    ```
    如果不能创建/nix目录，请进入安全模式使用csrutil关闭SIP


2.  添加home-manager channel

    ```console
    $ nix-channel --add https://github.com/clojurians-org/home-manager/archive/master.tar.gz home-manager
    $ nix-channel --update home-manager
    ```


3.  安装home-manager工具

    ```console
    $ export NIX_PATH=~/.nix-defexpr/channels
    $ nix-shell '<home-manager>' -A install
    ```


使用方法
-------
 
1.  编写默认配置 ~/.config/nixpkgs/home.nix 或其它路径

    配置文件格式参见larluo-conf/home.nix

    软件清单见下一节

```nix
{ config, pkgs, ... }:

{
  programs.home-manager.enable = true;

  home.stateVersion = "19.09";

  
  environment.systemPackages = [
    pkgs.coreutils
    pkgs.inetutils
    pkgs.unixtools.netstat
    pkgs.findutils
    pkgs.dnsutils
    pkgs.gnused
    pkgs.less
    pkgs.gawk
    pkgs.procps
    pkgs.cron
    pkgs.nix-bundle

    pkgs.tmux
    pkgs.emacs
    pkgs.vim
    pkgs.cloc
    pkgs.git
    pkgs.gitAndTools.gitSVN
    pkgs.cachix

    pkgs.gcc
    pkgs.jre
    pkgs.cabal-install
    pkgs.obelisk
    pkgs.yarn
    pkgs.gradle
    pkgs.clojure
    pkgs.lombok
    pkgs.clang-tools
    pkgs.dhall
    pkgs.python38
    pkgs.maven
  ];


  services.postgresql = { 
    enable = true ; 
    package = pkgs.postgresql_11 ;
    dataDir = "/opt/nix-module/data/postgresql" ;
  } ;

}

```


2.  激活生效

    如果不指定-f选项，默认为~/.config/nixpkgs/home.nix文件
    ```console
    $ export NIX_PATH=~/.nix-defexpr/channels
    $ home-manager -f larluo-conf/home.nix  switch
    ```
    
软件清单
----------

1. 查看所有package
```console
$ nix-env -f  ~/.nix-defexpr/channels/nixpkgs -qaP
```

2. 查看所有module [参考 modules/module-list.nix]

核心模块
----------

1. 数据库模块
- redis
- postgresql
- mysql
- elasticsearch
- neo4j
- zookeeper
- kafka
- kafka schema-registry
- Kafka ksql

2. 官方未支持pakage(后续迁移)
- vue (darwin)
- clickhouse (darwin)
- wpsoffice (darwin)

开发模式
--------

1. 下载github到本地进行调试
    ```console
    $ git clone https://github.com/clojurians-org/home-manager.git
    $ cd home-manager
    $ nix-shell -A install
    $ home-manager -I home-manager=. -f larluo-conf/home.nix  switch
    ```
