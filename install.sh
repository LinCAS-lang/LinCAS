#! /bin/bash

echo Configuring libraries
echo gcc -c -o ./src/Internal/LibC/libc.o ./src/Internal/LibC/libc.c
gcc -c -o ./src/Internal/LibC/libc.o ./src/Internal/LibC/libc.c
echo ar rcs ./src/Internal/LibC/libc.a ./src/Internal/LibC/libc.o
ar rcs ./src/Internal/LibC/libc.a ./src/Internal/LibC/libc.o

if [ ! -d "./bin" ]; then
    echo Creating bin folder
    mkdir ./bin 
fi
if [ ! -d "/usr/local/lib/LinCAS/LinCAS" ]; then
    echo Creating LinCAS folder
    sudo mkdir -p /usr/local/lib/LinCAS/LinCAS
fi

if [ ! -d "/usr/local/lib/LinCAS/lib" ]; then
    echo Creating lib folder
    sudo mkdir -p /usr/local/lib/LinCAS/lib
fi

echo Compiling LinCAS...
crystal build ./src/LinCAS.cr -o ./bin/lincas --release --stats
echo Installing LinCAS...
sudo cp ./bin/lincas /usr/bin/lincas
sudo touch /usr/local/lib/LinCAS/LinCAS/VERSION
sudo cp ./VERSION /usr/local/lib/LinCAS/LinCAS/VERSION
echo Installing libraries...
sudo cp -r ./lib/test /usr/local/lib/LinCAS/lib
echo Finished

