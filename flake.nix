{
  description = "nix-track-pr";

  inputs = {
    nixpkgs = {
      url = "nixpkgs/nixos-unstable";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let
      packages =
        system:
        import nixpkgs {
          inherit system;
        };
      forAllSystems =
        function:
        nixpkgs.lib.genAttrs [
          "aarch64-linux"
          "aarch64-darwin"
          "x86_64-darwin"
          "x86_64-linux"
        ] (system: function (packages system));
    in
    {
      packages = forAllSystems (pkgs: {
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.nix-track-pr;
        nix-track-pr = pkgs.callPackage ./package.nix { };
      });
      devShells = forAllSystems (pkgs: {
        default = self.devShells.${pkgs.stdenv.hostPlatform.system}.zig_0_15;
        zig_0_15 = pkgs.mkShell {
          name = "nix-track-pr";
          nativeBuildInputs = [
            pkgs.zig_0_15
            pkgs.pinact
          ];
        };
      });
    };
}
