{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      llvm_version = "18";
    in
    {
      packages.x86_64-linux.default =
        with import nixpkgs { system = "x86_64-linux"; };
        stdenv.mkDerivation rec {
          name = "llvm";
          buildInputs = [
            bashInteractive
            clang-tools_18
            cmake
            llvmPackages_18.clang
            llvmPackages_18.llvm
            mold
            ncurses
            ninja
            python3
            zlib
          ];

          propagateBuildInputs = [
            ncurses
            zlib
          ];

          # where to find libgcc
          NIX_LDFLAGS = "-L${gccForLibs}/lib/gcc/${targetPlatform.config}/${gccForLibs.version} -L${pkgs.lib.makeLibraryPath buildInputs}";
          # teach clang about C startup file locations
          CFLAGS = "-B${gccForLibs}/lib/gcc/${targetPlatform.config}/${gccForLibs.version} -B ${stdenv.cc.libc}/lib --gcc-toolchain=${gcc}";

          cmakeFlags = [
            "-DC_INCLUDE_DIRS=${pkgs.llvmPackages_18.stdenv.cc.libc.dev}/include"
            "-GNinja"

            "-DLLVM_INSTALL_TOOLCHAIN_ONLY=ON"

            "-DCMAKE_BUILD_TYPE=Release"
            "-DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
            "-DCMAKE_CXX_FLAGS=-march=native"
            "-DCMAKE_C_COMPILER_LAUNCHER=ccache"
            "-DCMAKE_C_FLAGS=-march=native"
            "-DLLVM_ENABLE_PROJECTS=clang;clang-tools-extra"
            "-DLLVM_ENABLE_RUNTIMES=compiler-rt;openmp"
            "-DLLVM_OPTIMIZED_TABLEGEN=ON"
            "-DLLVM_PARALLEL_LINK_JOBS=2"
            "-DLLVM_TARGETS_TO_BUILD=X86"
            "-DLLVM_USE_LINKER=mold"
          ];

          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath buildInputs}:${gccForLibs.lib}/lib:$LD_LIRARY_PATH";

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

            export CPATH=$(buildcpath $NIX_CFLAGS_COMPILE $(<${pkgs.llvmPackages_18.clang}/nix-support/libc-cflags)):${stdenv.cc}/resource-root/include
            export CPLUS_INCLUDE_PATH=$(buildcpath $NIX_CFLAGS_COMPILE $(<${pkgs.llvmPackages_18.clang}/nix-support/libcxx-cxxflags) $(<${stdenv.cc}/nix-support/libc-cflags)):${stdenv.cc}/resource-root/include
          '';
        };
    };
}
