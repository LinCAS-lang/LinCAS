
require "../../src/Core"
require "colorize"

macro test(name)
    def {{name.id}}
        {{yield}}
    end
    {{name.id}}
end

macro spec(specification)
    puts
    puts {{specification}}.colorize.light_blue
end

macro assert_eq(val1,val2)
    if {{val1}} == {{val2}}
        puts "      Test passed".colorize.green
    else
        puts "      Test failed".colorize.red
    end
end

macro does(act)
    puts "    #{ {{act}} }"
end

macro file(name)
    puts "File: #{ {{name}}.colorize.mode(:underline).blue}"
end
