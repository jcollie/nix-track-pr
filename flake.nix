# SPDX-FileCopyrightText: © 2025 Jeffrey C. Ollie <jeff@ocjtech.us>
# SPDX-License-Identifier: MIT

{
  description = "nix-track-pr";

  inputs = {
    nixpkgs = {
      url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    };
    zig = {
      url = "git+https://git.ocjtech.us/jeff/zig-overlay.git";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      zig,
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
        nix-track-pr = pkgs.callPackage ./package.nix {
          zig_0_16 = zig.packages.${pkgs.stdenv.hostPlatform.system}.master;
        };
      });
      devShells = forAllSystems (pkgs: {
        default = self.devShells.${pkgs.stdenv.hostPlatform.system}.zig_0_16;
        zig_0_16 = pkgs.mkShell {
          name = "nex-track-pr";
          nativeBuildInputs = [
            zig.packages.${pkgs.stdenv.hostPlatform.system}.master
            pkgs.pinact
            pkgs.reuse
          ];
        };
      });
    };
}
