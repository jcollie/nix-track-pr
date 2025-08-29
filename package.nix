{
  lib,
  stdenv,
  gh,
  git,
  makeWrapper,
  zig_0_15,
}:
let
  zig_hook = zig_0_15.hook.overrideAttrs {
    zig_default_flags = "-Dcpu=baseline -Doptimize=ReleaseFast --color off";
  };
in
stdenv.mkDerivation {
  pname = "nix-track-pr";
  version = "0.2.0";
  src = ./.;
  nativeBuildInputs = [
    makeWrapper
    zig_hook
  ];
  postFixup = ''
    wrapProgram $out/bin/nix-track-pr \
      --set PATH ${
        lib.makeBinPath [
          gh
          git
        ]
      }
  '';
  meta = {
    homepage = "https://github.com/jcollie/nix-track-pr";
    license = lib.licenses.mit;
    mainProgram = "nix-track-pr";
  };
}
