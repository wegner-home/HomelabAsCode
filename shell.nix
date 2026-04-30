{ pkgs ? import <nixpkgs> {
    config = {
      allowUnfree = true;
    };
  }
,
}:
pkgs.mkShell {
  name = "stackforge-dev";
  buildInputs = with pkgs; [
    # Build tools
    gnumake
    git
    docker
    docker-compose
    yq
    jq
    openssl

    # Runtime dependencies (tools stackforge wraps)
    ansible
    terraform
    sops
    age
    fluxcd
    kubernetes-helm
    python313Packages.pip
    python313Packages.pyyaml

  ];
  shellHook = ''
    export SOPS_AGE_KEY_FILE="$PWD/secrets/sops/keys.txt"

    # Alias for stackforge
    # Clear Screen
    clear
    echo "Welcome to the development environment!"
    echo "SOPS_AGE_KEY_FILE is set to:"
    echo "$SOPS_AGE_KEY_FILE"
  '';

}
