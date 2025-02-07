{
  inputs = {
    nixpkgs.url = "flake:nixpkgs";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    pre-commit-hooks-nix = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # To import a flake module
        # 1. Add foo to inputs
        # 2. Add foo as a parameter to the outputs function
        # 3. Add here: foo.flakeModule
        inputs.pre-commit-hooks-nix.flakeModule
        inputs.treefmt-nix.flakeModule

      ];
      debug = true;


      flake = {
        # Put your original flake attributes here.
      };
      #systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      systems = [
        # systems for which you want to build the `perSystem` attributes
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
      ];
      # perSystem = { config, self', inputs', pkgs, system, ... }: {
      perSystem = { config, pkgs, system, ... }:
        {
          # Per-system attributes can be defined here. The self' and inputs'
          # module parameters provide easy access to attributes of the same
          # system.
          #  inherit pkgs;

          # Allow unfree packages.

          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
            };
          };
          devShells.default =
            pkgs.mkShell rec {
              #Add executable packages to the nix-shell environment.
              packages = with pkgs; [
                (python3.withPackages (python-pkgs: with python-pkgs; [
                  flask
                  psycopg
                  psycopg.pool
                  waitress
                  requests
                  redis
                ]))
                kubernetes-helm
                # https://wiki.nixos.org/wiki/Google_Cloud_SDK
                (google-cloud-sdk.withExtraComponents (with pkgs.google-cloud-sdk.components; [
                  gke-gcloud-auth-plugin
                ]))
                kubectl
                terraform
                redis
                tfsec
                tflint
              ];

              shellHook = ''
                # export DEBUG=1
                # terraform init?
                # gcloud container clusters get-credentials primary # primary -> name of GKE cluster
                # gcloud auth configure-docker europe-docker.pkg.dev
              '';

              # images names:
              # agisit-frontend
              # agisit-kgtolb
              # agisit-bmi
            };


          pre-commit = {
            check.enable = true;
            settings.hooks = {
              actionlint.enable = true;
              treefmt.enable = true;
              #      terraform-validate.enable = true;
              # Default is to use opentofu.
              #     terraform-validate.entry = "${pkgs.terraform}/bin/terraform validate";
              #    terraform-validate.package = pkgs.terraform;
              commitizen = {
                enable = true;
                description = "Check whether the current commit message follows commiting rules. Allow empty commit messages by default, because they typically indicate to Git that the commit should be aborted.";
                entry = "${pkgs.commitizen}/bin/cz check --allow-abort --commit-msg-file";
                stages = [ "commit-msg" ];
              };
              gitleaks = {
                enable = true;
                name = "gitleaks";
                description = "Prevents commiting secrets";
                entry = "${pkgs.gitleaks}/bin/gitleaks protect --verbose --redact --staged";
                pass_filenames = false;
              };
              tflint = {
                enable = false;
                name = "tflint";
                description = "Static analysis powered security scanner for terraform code";
                entry = "${pkgs.tfsec}/bin/tfsec";
                pass_filenames = false;
              };
              tfsec = {
                enable = false;
                name = "tfsec";
                description = "A Pluggable Terraform Linter";
                entry = "${pkgs.tflint}/bin/tflint";
                pass_filenames = false;
              };
            };
          };
          treefmt.projectRootFile = ./flake.nix;
          treefmt.programs = {
            nixpkgs-fmt.enable = true;
            shfmt.enable = true;
            mdformat.enable = true;
            deadnix.enable = true;
            statix.enable = true;
            ruff-check.enable = true;
            ruff-format.enable = true;
            terraform.enable = true;
            terraform.package = pkgs.terraform;
            # prettier.enable = true;
          };
        };
    };
}

