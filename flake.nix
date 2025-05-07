{

  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];

    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
  
  inputs = {

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      uv2nix,
      pyproject-nix,
      pyproject-build-systems,
    }@inputs:
    let
      package = "dataset";
    in
      flake-utils.lib.eachDefaultSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system;
                                  config.allowUnfree = true;
                                };

          cudaLibs = [
            pkgs.cudaPackages.cudnn
            pkgs.cudaPackages.nccl
            pkgs.cudaPackages.cutensor
            pkgs.cudaPackages.cusparselt
            pkgs.cudaPackages.libcublas
            pkgs.cudaPackages.libcusparse
            pkgs.cudaPackages.libcusolver
            pkgs.cudaPackages.libcurand
            pkgs.cudaPackages.cuda_gdb
            pkgs.cudaPackages.cuda_nvcc
            pkgs.cudaPackages.cuda_cudart
            pkgs.cudaPackages.cudatoolkit
            pkgs.cudaPackages.cuda_nvml_dev
          ];

          cudaLDLibraryPath = pkgs.lib.makeLibraryPath cudaLibs;

          pyprojectOverrides = final: prev: {
            # Implement build fixups here.
            # Note that uv2nix is _not_ using Nixpkgs buildPythonPackage.
            # It's using https://pyproject-nix.github.io/pyproject.nix/build.html
            torch = prev.torch.overrideAttrs (old: {
              buildInputs = (old.buildInputs or [ ]) ++ cudaLibs;
            });
            torchmetrics = prev.torchmetrics.overrideAttrs (old: {
              buildInputs = (old.buildInputs or [ ]) ++ cudaLibs;
              postfixup = ''
                          addAutoPatchelfSearchPath "${final.torch}"
                        '';
            });
            nvidia-cusolver-cu12 = prev.nvidia-cusolver-cu12.overrideAttrs (old: {
              buildInputs = (old.buildInputs or []) ++ cudaLibs;
            });
            nvidia-cusparse-cu12 = prev.nvidia-cusparse-cu12.overrideAttrs (old: {
              buildInputs = (old.buildInputs or []) ++ cudaLibs;
            });
          };


          python = pkgs.python311;
          
          baseSet = pkgs.callPackage pyproject-nix.build.packages {
            inherit python;
          };
          
          pythonSet = baseSet.overrideScope (
            pkgs.lib.composeManyExtensions [
              pyproject-build-systems.overlays.default
              #            overlay
              pyprojectOverrides
            ]
          );

          venvName = "brai";
          workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
          venv = pythonSet.mkVirtualEnv "${venvName}" workspace.deps.default;

          # ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_14;

          ocamlPackages = pkgs.ocamlPackages;


          lwt-eio = ocamlPackages.buildDunePackage {
            pname = "lwt_eio";
            version = "v0.5.1"; 
            src = pkgs.fetchFromGitHub {
              owner = "ocaml-multicore";
              repo = "lwt_eio";
              rev = "v0.5.1";
              sha256 = "sha256-H6h7EabNSz7cK8RoY2gqR2FSJ+Yqb3fxKe8sA82sk8E";
            };

            buildInputs = [
              ocamlPackages.mdx
              ocamlPackages.eio_main
              ocamlPackages.eio
              ocamlPackages.lwt
              ocamlPackages.lwt_ppx
              ocamlPackages.uri
            ];

            dontDetectOcamlConflicts = true;
            
          };

          
          capnp-rpc = ocamlPackages.buildDunePackage {
            pname = "capnp-rpc";
            version = "v2.0"; 
            src = pkgs.fetchFromGitHub {
              owner = "mirage";
              repo = "capnp-rpc";
              rev = "v2.0";
              sha256 = "sha256-VRjFyNWUYShzXhML5QrEvybyYCKRQJZf4Xunc1uKg8E";
            };

            buildInputs = [
              ocamlPackages.logs
              ocamlPackages.fmt
              ocamlPackages.astring
              ocamlPackages.uri
              ocamlPackages.eio
              ocamlPackages.stdint
              ocamlPackages.capnp
              ocamlPackages.lwt
              pkgs.capnproto
            ];

            nativeBuildInputs = [
              ocamlPackages.capnp
              pkgs.capnproto
            ];
            
          };

          capnp-rpc-lwt = ocamlPackages.buildDunePackage {
            pname = "capnp-rpc-lwt";
            version = "v2.0"; 
            src = pkgs.fetchFromGitHub {
              owner = "mirage";
              repo = "capnp-rpc";
              rev = "v2.0";
              sha256 = "sha256-VRjFyNWUYShzXhML5QrEvybyYCKRQJZf4Xunc1uKg8E";
            };

            buildInputs = [
              ocamlPackages.eio
              ocamlPackages.uri
              ocamlPackages.logs
              capnp-rpc
              lwt-eio
              ocamlPackages.capnp
              pkgs.capnproto
              ocamlPackages.astring
              ocamlPackages.lwt
            ];

          };

          extunix = ocamlPackages.buildDunePackage {
            pname = "extunix";
            version = "v0.4.0"; 
            src = pkgs.fetchFromGitHub {
              owner = "ygrek";
              repo = "extunix";
              rev = "v0.4.0";
              sha256 = "sha256-Mjv7OiRbnvT6ox+RSjlfywkiJxUOHRHZp8XwPFeOyVY";
            };

            buildInputs = [
              ocamlPackages.dune-configurator
              ocamlPackages.ppxlib
              ocamlPackages.ocaml
              ocamlPackages.base
              ocamlPackages.findlib
            ];

          };


          capnp-rpc-net = ocamlPackages.buildDunePackage {
            pname = "capnp-rpc-net";
            version = "v2.0"; 
            src = pkgs.fetchFromGitHub {
              owner = "mirage";
              repo = "capnp-rpc";
              rev = "v2.0";
              sha256 = "sha256-VRjFyNWUYShzXhML5QrEvybyYCKRQJZf4Xunc1uKg8E";
            };

            buildInputs = [
              ocamlPackages.eio
              ocamlPackages.uri
              ocamlPackages.logs
              capnp-rpc
              lwt-eio
              ocamlPackages.capnp
              pkgs.capnproto
              ocamlPackages.astring
              ocamlPackages.cmdliner
              extunix
              ocamlPackages.prometheus
              ocamlPackages.ptime
              ocamlPackages.base64
              ocamlPackages.tls-eio
              ocamlPackages.findlib
            ];

          };

          
          capnp-rpc-unix = ocamlPackages.buildDunePackage {
            pname = "capnp-rpc-unix";
            version = "v2.0"; 
            src = pkgs.fetchFromGitHub {
              owner = "mirage";
              repo = "capnp-rpc";
              rev = "v2.0";
              sha256 = "sha256-VRjFyNWUYShzXhML5QrEvybyYCKRQJZf4Xunc1uKg8E";
            };

            buildInputs = [
              ocamlPackages.eio
              ocamlPackages.uri
              ocamlPackages.logs
              capnp-rpc
              lwt-eio
              ocamlPackages.capnp
              pkgs.capnproto
              ocamlPackages.astring
              ocamlPackages.cmdliner
              ocamlPackages.prometheus
              ocamlPackages.ptime
              ocamlPackages.base64
              ocamlPackages.tls-eio              
              extunix
              capnp-rpc-net
              ocamlPackages.findlib
            ];

          };
                    solver-0install = ocamlPackages.buildDunePackage {
            pname = "0install-solver";
            version = "v2.18"; 
            src = pkgs.fetchFromGitHub {
              owner = "0install";
              repo = "0install";
              rev = "v2.18";
              sha256 = "sha256-CxADWMYZBPobs65jeyMQjqu3zmm2PgtNgI/jUsYUp8I";
            };

            # buildInputs = [
            # ];
          };
          opam-0install-solver = ocamlPackages.buildDunePackage {
            pname = "opam-0install";
            version = "v0.5"; 
            src = pkgs.fetchFromGitHub {
              owner = "ocaml-opam";
              repo = "opam-0install-solver";
              rev = "v0.5";
              sha256 = "sha256-GvARNrqtc4R5gSJj6yWjSTr9rYuxUU4sLJLguUWiPhg";
            };

            buildInputs = [
              ocamlPackages.dune-configurator
              ocamlPackages.ppxlib
              ocamlPackages.fmt
              ocamlPackages.cmdliner
              ocamlPackages.opam-state
              solver-0install
            ];
          };
          opam-0install-cudf = ocamlPackages.buildDunePackage {
            pname = "opam-0install-cudf";
            version = "v0.5.0"; 
            src = pkgs.fetchFromGitHub {
              owner = "ocaml-opam";
              repo = "opam-0install-cudf";
              rev = "v0.5.0";
              sha256 = "sha256-TETfvR1Di4c8CylsKnMal/GfQcqMSr36o7511u1bYYs";
            };

            buildInputs = [
              ocamlPackages.cudf
              ocamlPackages.dune-configurator
              ocamlPackages.ppxlib
              opam-0install-solver
              solver-0install
            ];
          };
          opam-solver = ocamlPackages.buildDunePackage {
            pname = "opam-solver";
            version = "v2.3.0";
            src = pkgs.fetchFromGitHub {
              owner = "ocaml";
              repo = "opam";
              rev = "2.3.0";
              sha256 = "sha256-ZU11fWiS4hdbbzYytudTK8M1O6r51HRZ+ASO+VxvekE";
            };

            buildInputs = [
              pkgs.opam-installer
              ocamlPackages.re
              ocamlPackages.core_unix
              ocamlPackages.ocamlgraph
              ocamlPackages.jsonm
              ocamlPackages.sha
              ocamlPackages.mccs
              ocamlPackages.base64
              ocamlPackages.cmdliner
              ocamlPackages.dose3
              ocamlPackages.spdx_licenses
              ocamlPackages.opam-file-format
              ocamlPackages.swhid_core
              ocamlPackages.opam-repository
              ocamlPackages.opam-core
              ocamlPackages.opam-file-format
              ocamlPackages.opam-state
              opam-0install-cudf
              solver-0install
            ];
            
            nativeBuildInputs = [
              pkgs.curl
              pkgs.wget
              pkgs.gcc14
            ];

          };

          opam = ocamlPackages.buildDunePackage {
            pname = "opam-client";
            version = "v2.3.0";
            src = pkgs.fetchFromGitHub {
              owner = "ocaml";
              repo = "opam";
              rev = "2.3.0";
              sha256 = "sha256-ZU11fWiS4hdbbzYytudTK8M1O6r51HRZ+ASO+VxvekE";
            };

            buildInputs = [
              pkgs.opam-installer
              ocamlPackages.re
              ocamlPackages.core_unix
              ocamlPackages.ocamlgraph
              ocamlPackages.jsonm
              ocamlPackages.sha
              ocamlPackages.mccs
              ocamlPackages.base64
              ocamlPackages.cmdliner
              ocamlPackages.dose3
              ocamlPackages.spdx_licenses
              ocamlPackages.opam-file-format
              ocamlPackages.swhid_core
              ocamlPackages.opam-repository
              ocamlPackages.opam-core
              ocamlPackages.opam-file-format
              ocamlPackages.opam-state
              opam-0install-cudf
              opam-solver
              solver-0install
            ];
            
            nativeBuildInputs = [
              pkgs.curl
              pkgs.wget
              pkgs.gcc14
            ];

          };

        in
          {

            devShells.default = with pkgs; mkShell {
              name = "brai-env";



              
              buildInputs = [
                #pkgs.gmp
                pkgs.coq_8_19
                pkgs.coqPackages_8_19.coq-lsp
                #scope.${package}
                ocamlPackages.base
                ocamlPackages.ocaml
                ocamlPackages.dune_3
                ocamlPackages.ocaml-lsp
                ocamlPackages.utop
                ocamlPackages.findlib
                ocamlPackages.core
                ocamlPackages.capnp
                ocamlPackages.ocamlformat
                ocamlPackages.ounit
                ocamlPackages.yojson
                ocamlPackages.camlzip
                ocamlPackages.zarith
                ocamlPackages.xxhash
		            ocamlPackages.ocamlgraph
                ocamlPackages.eio
                ocamlPackages.astring
                ocamlPackages.uri
                ocamlPackages.cmdliner
                ocamlPackages.base64
                ocamlPackages.mirage-crypto
                ocamlPackages.mirage-crypto-rng
                ocamlPackages.prometheus
                ocamlPackages.ptime
                ocamlPackages.tls-eio
                ocamlPackages.bos
                ocamlPackages.dune-site
                ocamlPackages.opam-repository
                ocamlPackages.dose3
                ocamlPackages.opam-state
                ocamlPackages.mccs
                pkgs.opam
                # pkgs.coqPackages.ExtLib
                # pkgs.coqPackages.mathcomp-ssreflect
                # pkgs.coqPackages.mathcomp-ssreflect
                # pkgs.coqPackages.mathcomp
                pkgs.git
	              pkgs.libGLU
	              pkgs.libGL
	              pkgs.linuxPackages.nvidia_x11
                pkgs.cudaPackages.cudatoolkit
                pkgs.cudaPackages.cudnn
                pkgs.uv
                pkgs.basedpyright
                pkgs.devpod
                pkgs.py-spy
                pkgs.capnproto
                pkgs.graphviz
		            pkgs.xxHash
                capnp-rpc
                capnp-rpc-lwt
                capnp-rpc-unix
                capnp-rpc-net
                lwt-eio
                extunix
                opam
                opam-solver
                opam-0install-cudf
                opam-0install-solver
                solver-0install
                #            venv
              ];


              shellHook = ''
          unset PYTHONPATH
          export CUDA_PATH=${pkgs.cudaPackages.cudatoolkit}
          export CUDNN_PATH=${pkgs.cudaPackages.cudnn.lib}
          export PATH=$CUDA_PATH/bin:$CUDNN_PATH/bin:$PATH
          export LD_LIBRARY_PATH=${pkgs.linuxPackages.nvidia_x11}/lib:$CUDA_PATH/lib:$CUDNN_PATH/lib
          export EXTRA_LDFLAGS="-L${pkgs.linuxPackages.nvidia_x11}/lib -L$CUDA_PATH/lib -L$CUDNN_PATH/lib"
          export EXTRA_CCFLAGS="-I$CUDA_PATH/include -I${pkgs.cudaPackages.cuda_nvml_dev}/include"
          export XLA_FLAGS=--xla_gpu_cuda_data_dir=$CUDA_PATH
          export DUNE_CACHE=disabled
          export COQPATH=${pkgs.coq_8_19}/lib/coq/user-contrib:$COQPATH;
          export CAML_LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
            pkgs.coq_8_19
            ocamlPackages.findlib
          ]}:${pkgs.coq_8_19}/lib/stublibs:$CAML_LD_LIBRARY_PATH;
        '';
              
            };
          });
}