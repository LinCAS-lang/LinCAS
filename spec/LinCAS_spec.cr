require "./spec_helper"

describe LinCAS do 

    it "Creates needed folders" do 
        [
        Process.run("mkdir",%w|
            bin
        |),

        Process.run("sudo",%w|
            mkdir
            /usr/lib/LinCAS
        |)
        ].each do |res|
            res.exit_status.should eq(0)
        end
    end

    it "Compiles libraries" do

        [
        Process.run("gcc",%w|
            -c
            -o
            src/Internal/LibC/libc.o
            src/Internal/LibC/libc.c
        |,output: STDOUT, input: STDIN, error: STDERR),

        Process.run("ar",%w|
            rcs
            src/Internal/LibC/libc.a
            src/Internal/LibC/libc.o
        |,output: STDOUT, input: STDIN, error: STDERR)
        
        ].each do |res|
            res.exit_status.should eq(0)
        end
    end

    it "Builds LinCAS" do
        # Building the interpreter
        Process.run("crystal",%w|
            build
            ./src/LinCAS.cr
            -o
            ./bin/lincas
            --no-debug
            --release
            --stats
            --cross-compile
        |,output: STDOUT, input: STDIN, error: STDERR).exit_status.should eq(0)
    end

    it "Copies the binaries into /usr/bin folder" do
        Process.run("sudo",%w|
            cp
            ./bin/lincas /usr/bin/lincas
        |,output: STDOUT, input: STDIN, error: STDERR).exit_status.should eq(0)
    end

    it "Runs the specs" do 
        Process.run("lincas",%w|
            test/LinCAS_test.lc
        |).exit_status.should eq(0)
    end
end