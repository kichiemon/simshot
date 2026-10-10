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
          sha256 = "9585de2a75ce66971e9fec304475873cf3d4d25f981f4c274bff3a272e81b99a";
        };
        x86_64-darwin = {
          name = "simshot-macos-x86_64";
          sha256 = "5273399e9b2dce73341ee18e772091d928f6565f085c6d8e4ad4e0a6bbf13f03";
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
