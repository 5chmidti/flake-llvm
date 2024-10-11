{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };
      llvm_version = "18";
      llvm = pkgs."llvmPackages_${llvm_version}";
    in
    {
      packages.${system}.default =
        #useMoldLinker 
        llvm.stdenv.mkDerivation rec {
          name = "llvm";
          buildInputs = [
            pkgs.cmake
            pkgs.libgcc
            pkgs.mold-wrapped
            pkgs.ncurses
            pkgs.ninja
            pkgs.python3
            pkgs.zlib
          ];

          nativeBuildInputs = [
            pkgs.bashInteractive
            pkgs.cmake
            llvm.clang-tools
            pkgs.mold-wrapped
            pkgs.ncurses
            pkgs.ninja
            pkgs.python3
            pkgs.zlib
          ];

          propagateBuildInputs = [
            pkgs.ncurses
            pkgs.zlib
          ];

          # where to find libgcc
          NIX_LDFLAGS = "-L${llvm.stdenv.cc.libc}/lib -L${llvm.stdenv.cc.cc}/lib";
          # teach clang about C startup file locations
          CFLAGS = "-B${llvm.stdenv.cc.libc}/lib -B${pkgs.gccForLibs}/lib/gcc/${pkgs.targetPlatform.config}/${pkgs.gccForLibs.version} --gcc-toolchain=${pkgs.gcc} ${builtins.readFile "${llvm.stdenv.cc}/nix-support/cc-cflags"}";
          CXXFLAGS = CFLAGS;
          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath buildInputs}:${pkgs.gcc.cc.lib}/lib:$LD_LIRARY_PATH";

          cmakeFlags = [
            "-DC_INCLUDE_DIRS=${llvm.stdenv.cc.libc.dev}/include"
            "-GNinja"

            "-DLLVM_INSTALL_TOOLCHAIN_ONLY=ON"

            "-DCMAKE_EXE_LINKER_FLAGS=\"-L${pkgs.libgcc}/lib\""

            "-DCMAKE_BUILD_TYPE=Release"
            "-DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
            "-DCMAKE_C_COMPILER_LAUNCHER=ccache"
            "-DLLVM_ENABLE_PROJECTS=clang;clang-tools-extra"
            "-DLLVM_ENABLE_RUNTIMES=compiler-rt;openmp"
            "-DLLVM_OPTIMIZED_TABLEGEN=ON"
            "-DLLVM_PARALLEL_LINK_JOBS=2"
            "-DLLVM_TARGETS_TO_BUILD=X86"
            "-DLLVM_USE_LINKER=mold"
          ];

          shellHook = ''
            buildcpath() {
              local path after
              while (( $# )); do
                case $1 in
                    -isystem)
                        shift
                        path=$path''${path:+':'}$1
                        ;;
                    -idirafter)
                        shift
                        after=$after''${after:+':'}$1
                        ;;
                esac
                shift
              done
              echo $path''${after:+':'}$after
            }

            export CPATH=$(buildcpath $NIX_CFLAGS_COMPILE $(<${llvm.clang}/nix-support/libc-cflags)):${llvm.stdenv.cc}/resource-root/include
            export CPLUS_INCLUDE_PATH=$(buildcpath $NIX_CFLAGS_COMPILE $(<${llvm.clang}/nix-support/libcxx-cxxflags) $(<${llvm.stdenv.cc}/nix-support/libc-cflags)):${llvm.stdenv.cc}/resource-root/include
          '';
        };
    };
}
