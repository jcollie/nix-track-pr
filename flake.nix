{
  description = "nix-track-pr";

  inputs = {
    nixpkgs = {
      url = "nixpkgs/nixos-unstable";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    packages = system:
      import nixpkgs {
        inherit system;
      };
    forAllSystems = function:
      nixpkgs.lib.genAttrs [
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
      ] (system: function (packages system));
  in {
    packages = forAllSystems (pkgs: {
      default = self.packages.${pkgs.system}.nix-track-pr;
      nix-track-pr = pkgs.callPackage ./package.nix {};
    });
  };
}
