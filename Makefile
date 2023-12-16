
LIB = /usr/local/Cellar/llvm@14/14.0.6/lib/

all: build

setup:
	mkdir /usr/local/lib/LinCAS/LinCAS
	mkdir -p /usr/local/lib/LinCAS/lib

python:

build:
	crystal build --error-trace src/LinCAS.cr --link-flags=-Wl,-lintl -Duse_lp -D:use_pcre2 -o bin/lincas

doc: util/DocGenerator.cr
	crystal build util/DocGenerator.cr -o bin/doc_generator
	./bin/doc_generator .

clean:
	rm bin/doc_generator