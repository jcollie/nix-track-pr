#!/usr/bin/env nu

def progress_report [step: int, total: int] {
  let pct = ($step / $total * 100) | into string --decimals 0
  print -n $"\u{1b}]9;4;1;($pct)\u{1b}\\" | ignore
}

def progress_reset [] {
  print -n $"\u{1b}]9;4;0;\u{1b}\\" | ignore
}

def track [pr: int] {

  let branches = ["staging" "staging-next" "master" "nixos-unstable-small" "nixpkgs-unstable" "nixos-unstable"] 
  let steps = ($branches | length) + 1
  progress_report 1 $steps
  print $"($pr) getting data from GitHub"
  let result = gh pr view $in --json mergeCommit,state,title | complete
  if $result.exit_code != 0 { print $"($pr) does not appear to be a PR" | return }
  let data = $result.stdout | from json | match $in.state {
    "MERGED" => {pr: $pr, title: $in.title, commit: $in.mergeCommit.oid},
     _ => ( progress_reset | print $"($pr) has not been merged \(($in.state)\)" | return )
  }
  let results = $branches | enumerate | each {|e|
      progress_report ($e.index + 1) $steps | print $"($pr) checking ($e.item)" | git merge-base --is-ancestor $data.commit $e.item | complete | {
      branch: $e.item , status: (if $in.exit_code == 0 {"🟢"} else {"🔴"})
    }
  }
  progress_reset
  $results | each {|row| {pr: $data.pr, title: $data.title, $row.branch: $row.status }} | into record | flatten | first | print $in | ignore
}

def main [...prs: int] {
  let cachedir = [$env.HOME ".cache" "nix-track-pr"] | path join
  mkdir $cachedir
  let gitdir = [$cachedir "nixpkgs"] | path join
  if not ($gitdir | path exists) { git clone --bare https://github.com/NixOS/nixpkgs $gitdir }
  cd $gitdir
  git fetch origin --prune --no-write-fetch-head
  $prs | each {|pr| track $pr } | ignore
}
