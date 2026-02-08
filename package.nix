# SPDX-FileCopyrightText: © 2025 Jeffrey C. Ollie <jeff@ocjtech.us>
# SPDX-License-Identifier: MIT

{
  lib,
  stdenv,
  gh,
  git,
  makeWrapper,
  zig_0_16,
}:
stdenv.mkDerivation {
  pname = "nix-track-pr";
  version = "0.3.0";
  src = ./.;
  nativeBuildInputs = [
    makeWrapper
    zig_0_16
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
