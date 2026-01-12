{
  lib,
  stdenv,
  gh,
  git,
  makeWrapper,
  zig_0_15,
}:
stdenv.mkDerivation {
  pname = "nix-track-pr";
  version = "0.2.1";
  src = ./.;
  nativeBuildInputs = [
    makeWrapper
    zig_0_15
  ];
  dontSetZigDefaultFlags = true;
  zigBuildFlags = [
    "-Dcpu=baseline"
    "-Doptimize=ReleaseFast"
    "--color off"
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
