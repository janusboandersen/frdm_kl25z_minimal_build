# Clean, configure and build
# Janus, October 2025

rm -rf build   
cmake -S . -B build -G Ninja
cmake --build build -v
cmake --build build --target readme