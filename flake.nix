{
  description = "simshot - App Store screenshot capture CLI (simctl only, no XCUITest)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      # Prebuilt single binaries published to GitHub Releases.
      # `name` follows ubi's {project}-{os}-{arch} convention; sha256 is the
      # digest of the raw (extensionless) binary from the v0.2.1 release.
      assets = {
        aarch64-darwin = {
          name = "simshot-macos-arm64";
          sha256 = "3135afa8876deeceed9952054a8fd3d4f20cb21ee8a4ed36761ec9dddd797f42";
        };
        x86_64-darwin = {
          name = "simshot-macos-x86_64";
          sha256 = "bb811078be1359af157b326049a15179143afc7c16017b267a675d8c788a23b5";
        };
      };

      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          asset = assets.${system};
        in
        rec {
          simshot = pkgs.stdenv.mkDerivation {
            pname = "simshot";
            version = "0.2.1";

            src = pkgs.fetchurl {
              url = "https://github.com/kichiemon/simshot/releases/download/v${version}/${asset.name}";
              sha256 = asset.sha256;
            };

            dontUnpack = true;
            dontConfigure = true;
            dontBuild = true;
            dontFixup = true;

            installPhase = ''
              runHook preInstall
              install -Dm755 $src $out/bin/simshot
              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "App Store screenshot capture CLI (simctl only, no XCUITest)";
              homepage = "https://github.com/kichiemon/simshot";
              license = licenses.mit;
              platforms = platforms.darwin;
            };
          };

          default = simshot;
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/simshot";
        };
      });

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.swift
              pkgs.nodejs_22
            ];
          };
        });
    };
}
