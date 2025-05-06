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

          ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_14;         
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