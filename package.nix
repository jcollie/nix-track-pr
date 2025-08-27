{
  lib,
  stdenvNoCC,
  gh,
  git,
  nushell,
  makeWrapper,
}:
stdenvNoCC.mkDerivation {
  pname = "nix-track-pr";
  version = "0.0.1";
  src = ./.;
  nativeBuildInputs = [makeWrapper];
  buildInputs = [nushell];
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp ./nix-track-pr.nu $out/bin/nix-track-pr
    chmod a+x $out/bin/nix-track-pr

    runHook postInstall
  '';
  postFixup = ''
    wrapProgram $out/bin/nix-track-pr \
      --set PATH ${lib.makeBinPath [
      gh
      git
    ]}
  '';
}
