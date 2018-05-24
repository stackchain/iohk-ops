{ ... }:

with (import ./../lib.nix);

let
  iohk-pkgs = import ../default.nix {};

in {
  network.description = "Testnet Deployer";

  testnet-deployer = { config, pkgs, resources, ... }: {
    imports = [
      ./../modules/common.nix
      ./../modules/datadog.nix
      ./../modules/papertrail.nix
    ];

    services.dd-agent.tags = ["env:production" "depl:${config.deployment.name}" "role:deployer"];

    security.sudo.enable = true;
    security.sudo.wheelNeedsPassword = false;

    networking.hostName = "testnet-deployer";

    environment.systemPackages = (with iohk-pkgs; [
      iohk-ops
      terraform
      mfa
    ]) ++ (with pkgs; [
      gnupg
      nixops
      awscli
      jq
      yq
      python3
      htop
    ]);

    users.groups = {
      deployers = {};
      developers = {};
    };
    users.users = {
      # Re-deploy the deployer host itself,
      # and apply global terraform.
      deployer = {
        isNormalUser = true;
        description  = "Deploy the deployer";
        group        = "deployers";
        extraGroups  = [ "wheel" ];
        openssh.authorizedKeys.keys = devOpsKeys;
      };

      # Deploy testnet
      testnet = {
        isNormalUser = true;
        description  = "Testnet NixOps Deployer";
        group        = "deployers";
        openssh.authorizedKeys.keys = devOpsKeys;
      };

      # Deploy staging network
      staging = {
        description  = "Staging NixOps deployer";
        group        = "deployers";
        isNormalUser = true;
        openssh.authorizedKeys.keys = devOpsKeys;
      };

      # Deploy Hydra and agents
      infra = {
        description  = "CI NixOps deployer";
        group        = "deployers";
        isNormalUser = true;
        openssh.authorizedKeys.keys = devOpsKeys;
      };
    }
    # Normal users who can deploy developer clusters on AWS.
    // mapAttrs (name: keys: {
      group = "developers";
      isNormalUser = true;
      openssh.authorizedKeys.keys = keys;
    }) (developers // devOps);

    deployment.keys.tarsnap = {
      keyFile = ./../static/tarsnap-testnet-deployer.secret;
      destDir = "/var/lib/keys";
    };

    services.tarsnap = {
      enable = true;
      keyfile = "/var/lib/keys/tarsnap";
      archives.testnet-deployer = {
        directories = [
          # fixme: backups for each user
          "/home/infra/.ec2-keys"
          "/home/infra/.aws"
          "/home/infra/.nixops"
          "/etc/"
        ];
      };
    };

  };
}
