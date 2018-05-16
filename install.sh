#! /bin/bash

echo Configuring libraries
set -x
gcc -c -o ./src/Internal/LibC/libc.o ./src/Internal/LibC/libc.c
ar rcs ./src/Internal/LibC/libc.a ./src/Internal/LibC/libc.o
set +x
if [ ! -d "./bin" ]; then
    echo Creating bin folder
    mkdir ./bin 
fi
if [ ! -d "/usr/lib/LinCAS" ]; then
    echo Creating lib folder
    sudo mkdir /usr/lib/LinCAS
fi

echo Compiling LinCAS...
crystal build ./src/LinCAS.cr -o ./bin/lincas --no-debug
echo Installing LinCAS...
sudo cp ./bin/lincas /usr/bin/lincas
echo Finished

