
# Copyright (c) 2017-2018 Massimiliano Dal Mas
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

module LinCAS::Internal

    abstract struct BinaryOp < BaseS

        macro reduce_loop(val,tmp)
            while {{val}} != {{tmp}}
                {{tmp}} = {{val}}
                {{val}} = {{val}}.reduce
            end
        end

        property left,right 

        def initialize(@left : Sym, @right : Sym)
            super()
        end

        def reduce
            tmp   = @left 
            @left = @left.reduce 
            reduce_loop(@left,tmp)
            tmp    = @right 
            @right = @right.reduce 
            reduce_loop(@right,tmp)
        end

        def ==(obj : BinaryOp)
            return false unless self.class = obj.class
            return (self.left == obj.left) && (self.right == obj.right)
        end 

        @[AlwaysInline]
        def ==(obj)
            return false 
        end

        def depend?(obj)
            return (@left.depend? obj) || (@right.depend? obj)
        end

    end
    
end