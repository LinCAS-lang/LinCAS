require "./spec_helper"

describe LinCAS do 
    it "Installs LinCAS" do 

        # Creating needed folders
        Process.run("mkdir",%w|
            bin
        |)

        Process.run("sudo",%w|
            mkdir
            /usr/lib/LinCAS
        |)

        res = 0

        [
        # Compiling libraries
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
        |,output: STDOUT, input: STDIN, error: STDERR),

        # Building the interpreter
        Process.run("crystal",%w|
            build
            src/LinCAS.cr
            --no-debug
            --release
            --stats
            -o
            bin/lincas
        |,output: STDOUT, input: STDIN, error: STDERR),

        Process.run("sudo",%w|
            cp
            bin/lincas /usr/bin/lincas
        |,output: STDOUT, input: STDIN, error: STDERR)
    ].each do |res|
        res.exit_status.should eq(0)
    end
    
    end

    it "Runs the specs" do 
        Process.run("lincas",%w|
            test/LinCAS_test.lc
        |).exit_status.should eq(0)
    end
end