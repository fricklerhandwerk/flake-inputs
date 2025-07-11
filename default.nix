# SPDX-License-Identifier: MIT
rec {
  /**
    Convert number of seconds in the Unix epoch to a Gregorian calendar date and time

    This does not take into account leap seconds, which would require a table lookup.

    Courtesy of http://howardhinnant.github.io/date_algorithms.html via https://stackoverflow.com/a/32158604
    Variables renamed and commented for for clarity and readability.
  */
  datetime-from-timestamp =
    timestamp:
    let
      remainder = x: y: x - x / y * y;
      seconds-per-day = 86400;
      day-of-epoch = timestamp / seconds-per-day;
      seconds-of-day = remainder timestamp seconds-per-day;
      hour = seconds-of-day / 3600;
      minute = (remainder seconds-of-day 3600) / 60;
      second = remainder timestamp 60;

      day' = day-of-epoch + 719468; # internal representation of days, based on number of days between 0000-03-01 and 1970-01-01
      era =
        # 400-year interval of the Gregorian calendar
        (if day' >= 0 then day' else day' - (days-per-era - 1)) / days-per-era;
      days-per-era = 146097;
      day-of-era = day' - era * days-per-era;
      year-of-era =
        (day-of-era - day-of-era / 1460 + day-of-era / 36524 - day-of-era / (days-per-era - 1)) / 365;
      year' = year-of-era + era * 400; # internal representation of years
      day-of-year = day-of-era - (365 * year-of-era + year-of-era / 4 - year-of-era / 100);
      month' = (5 * day-of-year + 2) / 153; # internal representation of months
      day = day-of-year - (153 * month' + 2) / 5 + 1;
      month = month' + (if month' < 10 then 3 else -9);
      year = year' + (if month <= 2 then 1 else 0);
    in
    {
      inherit
        year
        month
        day
        hour
        minute
        second
        ;
    };

  /**
    Pad a string-coercible `input` with the given `fill` character to the desired `length`.
  */
  pad =
    length: fill: input:
    let
      str = toString input;
    in
    with builtins;
    assert stringLength str <= length;
    assert stringLength fill == 1;
    concatStringsSep "" (genList (_: fill) (length - stringLength str)) + str;

  # Format number of seconds in the Unix epoch as %Y%m%d%H%M%S.
  format-timestamp =
    timestamp:
    with builtins.mapAttrs (name: n: if name == "year" then pad 4 "0" n else pad 2 "0" n) (
      datetime-from-timestamp timestamp
    );
    "${year}${month}${day}${hour}${minute}${second}";

  /**
    Polyfill for the experimental `builtins.fetchTree`

    https://nix.dev/manual/nix/latest/language/builtins#builtins-fetchTree
  */
  fetchTree =
    info:
    if info.type == "github" then
      {
        outPath = fetchTarball (
          {
            url = "https://api.${info.host or "github.com"}/repos/${info.owner}/${info.repo}/tarball/${info.rev}";
          }
          // (if info ? narHash then { sha256 = info.narHash; } else { })
        );
        rev = info.rev;
        shortRev = builtins.substring 0 7 info.rev;
        lastModified = info.lastModified;
        lastModifiedDate = format-timestamp info.lastModified;
        narHash = info.narHash;
      }
    else if info.type == "git" then
      {
        outPath = builtins.fetchGit (
          {
            url = info.url;
            shallow = true;
            allRefs = true;
          }
          // (if info ? rev then { inherit (info) rev; } else { })
          // (if info ? ref then { inherit (info) ref; } else { })
          // (if info ? submodules then { inherit (info) submodules; } else { })
        );
        lastModified = info.lastModified;
        lastModifiedDate = format-timestamp info.lastModified;
        narHash = info.narHash;
        revCount = info.revCount or 0;
      }
      // (
        if info ? rev then
          {
            rev = info.rev;
            shortRev = builtins.substring 0 7 info.rev;
          }
        else
          { }
      )
    else if info.type == "path" then
      {
        outPath = builtins.path {
          path =
            if
              builtins.substring 0 1 info.path != "/"
            # XXX: Relative paths require an additional `src` attribute!
            #      This is supplied when being called by our own `import-flake`, but may not work elsewhere
            then
              "${info.src}/${info.path}"
            else
              info.path;
          sha256 = info.narHash;
        };
        narHash = info.narHash;
      }
    else if info.type == "tarball" then
      {
        outPath = fetchTarball (
          { inherit (info) url; } // (if info ? narHash then { sha256 = info.narHash; } else { })
        );
      }
    else if info.type == "gitlab" then
      {
        inherit (info) rev narHash lastModified;
        outPath = fetchTarball (
          {
            url = "https://${info.host or "gitlab.com"}/api/v4/projects/${info.owner}%2F${info.repo}/repository/archive.tar.gz?sha=${info.rev}";
          }
          // (if info ? narHash then { sha256 = info.narHash; } else { })
        );
        shortRev = builtins.substring 0 7 info.rev;
      }
    else if info.type == "sourcehut" then
      {
        inherit (info) rev narHash lastModified;
        outPath = fetchTarball (
          {
            url = "https://${info.host or "git.sr.ht"}/${info.owner}/${info.repo}/archive/${info.rev}.tar.gz";
          }
          // (if info ? narHash then { sha256 = info.narHash; } else { })
        );
        shortRev = builtins.substring 0 7 info.rev;
      }
    # TODO: Mercurial, tarball inputs, ...
    else
      throw "flake input has unsupported input type '${info.type}'";

  /**
    Import a flake from stable Nix.

    Modified from https://github.com/nix-community/dream2nix/blob/main/dev-flake/flake-compat.nix
    since neither https://github.com/nix-community/flake-compat nor https://github.com/edolstra/flake-compat
    are actively maintained.
  */
  import-flake =
    {
      src,
      overrides ? { },
    }:
    let
      lockFilePath = src + "/flake.lock";
      lockFile = builtins.fromJSON (builtins.readFile lockFilePath);

      # We can't import those from the Nixpkgs `lib`,
      # Since flake inputs are used to fetch Nixpkgs to begin with
      nameValuePair = name: value: { inherit name value; };
      mapAttrs' = f: set: builtins.listToAttrs (map (attr: f attr set.${attr}) (builtins.attrNames set));

      tree =
        let
          # Try to clean the source tree by using `fetchGit`, if this source tree is a valid Git repository.
          tryFetchGit =
            src:
            if isGit && !isShallow then
              let
                res = builtins.fetchGit src;
              in
              if res.rev == "0000000000000000000000000000000000000000" then
                removeAttrs res [
                  "rev"
                  "shortRev"
                ]
              else
                res
            else
              { outPath = src; };
          # Git worktrees have a file for .git, so we don't check the type of .git
          isGit = builtins.pathExists (src + "/.git");
          isShallow = builtins.pathExists (src + "/.git/shallow");
        in
        {
          lastModified = 0;
          lastModifiedDate = format-timestamp 0;
        }
        // (if src ? outPath then src else tryFetchGit src);

      rootOverrides = mapAttrs' (
        input: lockKey':
        let
          lockKey = if builtins.isList lockKey' then builtins.concatStringsSep "/" lockKey' else lockKey';
        in
        nameValuePair lockKey (overrides.${input} or null)
      ) lockFile.nodes.${lockFile.root}.inputs;

      allNodes = builtins.mapAttrs (
        key: node:
        let
          sourceInfo =
            if key == lockFile.root then
              tree
            else if rootOverrides.${key} or null != null then
              {
                type = "path";
                outPath = rootOverrides.${key};
                narHash = throw "import-flake: overriding narHash not implemented";
              }
            else
              fetchTree (node.info or { } // removeAttrs node.locked [ "dir" ] // { inherit src; });

          subdir = if key == lockFile.root then "" else node.locked.dir or "";

          # extra parenthesis so we build a string context only only once
          outPath = sourceInfo + ((if subdir == "" then "" else "/") + subdir);

          flake = import (outPath + "/flake.nix");

          inputs = builtins.mapAttrs (_inputName: inputSpec: allNodes.${resolveInput inputSpec}) (
            node.inputs or { }
          );

          # Resolve a input spec into a node name.
          # An input spec is either a node name, or a 'follows' path from the root node.
          resolveInput =
            inputSpec: if builtins.isList inputSpec then getInputByPath lockFile.root inputSpec else inputSpec;

          # Follow an input path (e.g. ["dwarffs" "nixpkgs"]) from the root node, returning the final node.
          getInputByPath =
            nodeName: path:
            if path == [ ] then
              nodeName
            else
              getInputByPath
                # Since this could be a 'follows' input, call resolveInput.
                (resolveInput lockFile.nodes.${nodeName}.inputs.${builtins.head path})
                (builtins.tail path);

          outputs = flake.outputs (inputs // { self = result; });

          result =
            outputs
            # `sourceInfo.outPath` does not necessarily match the `outPath` of the flake,
            # as the flake may be in a subdirectory of a source.
            # This is shadowed in the next `//`.
            // sourceInfo
            // {
              # This shadows `sourceInfo.outPath`.
              inherit outPath;
              inherit inputs;
              inherit outputs;
              inherit sourceInfo;
              _type = "flake";
            };
        in
        if node.flake or true then
          assert builtins.isFunction flake.outputs;
          result
        else
          sourceInfo
      ) lockFile.nodes;

      result =
        if !(builtins.pathExists lockFilePath) then
          let
            flake = import (tree + "/flake.nix");
            outputs = flake.outputs { self = result; };
            result =
              tree
              // {
                inherit outputs;
                inputs = { };
                _type = "flake";
                sourceInfo = tree;
              }
              // outputs;
          in
          result
        else if lockFile.version >= 5 && lockFile.version <= 7 then
          allNodes.${lockFile.root} // { self = allNodes.${lockFile.root}; }
        else
          throw "import-flake: lock file '${lockFilePath}' has unsupported version ${toString lockFile.version}";
    in
    result
    // {
      overrideInputs =
        ov:
        import-flake {
          inherit src;
          overrides = ov;
        };
    };

  /**
    Polyfill for the experimental `builtins.getFlake`

    https://nix.dev/manual/nix/latest/language/builtins#builtins-getFlake
  */
  getFlake = info: import-flake { src = fetchTree info; };

  /**
    Load a flake like `:lf` in `nix repl`
  */
  load-flake = flake: (import-flake { src = flake; }).self.outputs;
}
