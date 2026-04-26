{
  description = "Netie Open HBM -- reproducible toolchain pinning OSS CAD Suite 2026-04-02";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Pin OSS CAD Suite 2026-04-02 -- the binary release bundles
        # Yosys, nextpnr, Verilator, Icarus, SymbiYosys, GHDL, KLayout,
        # Magic, OpenROAD, and ABC at known-good versions.
        ossCadSuite = pkgs.stdenv.mkDerivation rec {
          pname = "oss-cad-suite";
          version = "2026-04-02";

          src = pkgs.fetchurl {
            url = "https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${version}/oss-cad-suite-linux-x64-${pkgs.lib.replaceStrings ["-"] [""] version}.tgz";
            # NOTE: Hash must be updated on first run. Use:
            #   nix-prefetch-url <url>
            sha256 = "sha256:0000000000000000000000000000000000000000000000000000";
          };

          nativeBuildInputs = [ pkgs.autoPatchelfHook ];
          buildInputs = with pkgs; [
            stdenv.cc.cc.lib
            zlib
            libffi
            ncurses
            tcl
            tk
            readline
            libusb1
            python3
          ];

          installPhase = ''
            mkdir -p $out
            cp -r * $out/
          '';

          meta = with pkgs.lib; {
            description = "OSS CAD Suite ${version} -- Yosys/nextpnr/Verilator/SymbiYosys/Icarus/GHDL/KLayout/Magic/OpenROAD";
            homepage = "https://github.com/YosysHQ/oss-cad-suite-build";
            license = licenses.asl20;
            platforms = platforms.linux ++ platforms.darwin;
          };
        };

        pythonEnv = pkgs.python311.withPackages (ps: with ps; [
          pip
          uv
          # Verification stack
          cocotb
          pytest
          # SiliconCompiler depends on these; we install SC itself via uv
          numpy
          pandas
          jsonschema
          packaging
          pyyaml
          requests
          # Documentation
          sphinx
          mkdocs
        ]);
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            ossCadSuite
            pythonEnv
            pkgs.gnumake
            pkgs.git
            pkgs.docker
            pkgs.podman
            pkgs.openems
            pkgs.ngspice
            pkgs.xschem
            pkgs.magic-vlsi
            pkgs.klayout
          ];

          shellHook = ''
            export OSS_CAD_SUITE_HOME=${ossCadSuite}
            export PATH=$OSS_CAD_SUITE_HOME/bin:$PATH

            echo ""
            echo "  Netie Open HBM developer shell"
            echo "  ------------------------------"
            echo "  OSS CAD Suite : $OSS_CAD_SUITE_HOME (2026-04-02)"
            echo "  Python        : $(python --version)"
            echo "  Verilator     : $(verilator --version 2>/dev/null | head -n1 || echo 'not on PATH')"
            echo "  Yosys         : $(yosys -V 2>/dev/null | head -n1 || echo 'not on PATH')"
            echo "  KLayout       : $(klayout -v 2>/dev/null || echo 'not on PATH')"
            echo ""
            echo "  Initialise the Python deps:"
            echo "    uv sync"
            echo ""
            echo "  Run the smoke test:"
            echo "    make smoke"
            echo ""
          '';
        };
      });
}
