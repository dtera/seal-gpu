git submodule update --init --recursive
cd extern/SEAL
rm -rf build && mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DSEAL_THROW_ON_TRANSPARENT_CIPHERTEXT=OFF -DCMAKE_INSTALL_PREFIX=./install
make
make install
cd ../../..

f_path="extern/SEAL/build/install/lib64/cmake/SEAL-4.0/SEALConfig.cmake"
row_num=$(awk -v pattern="^set.*SEAL_FOUND FALSE" '$0 ~ pattern {print NR}' "$f_path")
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "${row_num}s/FALSE/TRUE/" "$f_path"
else
  sed -i "${row_num}s/FALSE/TRUE/" "$f_path"
fi