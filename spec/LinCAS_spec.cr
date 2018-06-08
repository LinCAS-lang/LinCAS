require "./spec_helper"

describe LinCAS do 
    it "Runs the specs" do 
        Process.run("./bin/lincas",%w|
            test/LinCAS_test.lc
        |).exit_status.should eq(0)
    end
end
