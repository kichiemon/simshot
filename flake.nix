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
      # digest of the raw (extensionless) binary from the v0.2.2 release.
      assets = {
        aarch64-darwin = {
          name = "simshot-macos-arm64";
          sha256 = "3d511da4728d68dd901669b62a9821f91ce39a9c4f2a4948500c831854082647";
        };
        x86_64-darwin = {
          name = "simshot-macos-x86_64";
          sha256 = "38af28a571850b406d1044df57ed67e9a727a4d83382d59db63dbfc04ca8a934";
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
            version = "0.2.2";

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
