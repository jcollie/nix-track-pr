# nix-track-pr

A quick and dirty script for tracking the status of `nixpkgs` pull requests as
they work their way through the system to see which branches that they have been
merged into.

Requires that `gh` and `git` be available. When first run, this script will
checkout a copy of the `nixpkgs` repository to `~/.cache/nix-track-pr/nixpkgs`.
This takes around 6GB of disk space and many minutes to create on the first run.
Subsequent runs of the script will update the repository but that should not
take very long (depending on how long it has been since the last run).

