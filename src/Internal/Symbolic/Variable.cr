
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

    struct Variable < SBaseS

        getter name

        nan_ops

        def initialize(@name : String)
        end

        def +(obj : Variable) : Symbolic
            return Product.new(STWO,self) if self == obj 
            return Sum.new(self,obj)
        end

        def +(obj : BinaryOp) : Symbolic
            return obj + self
        end

        def +(obj : Negative) : Symbolic
            return self - obj.value 
        end

        def +(obj : Snumber) : Symbolic
            return self if obj == 0
            return Sum.new(self,obj)
        end

        def +(obj) : Symbolic
            return Sum.new(self,obj)
        end

        def opt_sum(obj : Variable) : Symbolic?
            return Product.new(STWO,self) if self == obj 
            return nil 
        end

        def -(obj : Variable) : Symbolic
            return SZERO if self == obj
            return Sub.new(self,obj)
        end

        def -(obj : Negative) : Symbolic
            return self + obj.value
        end

        def -(obj : Snumber) : Symbolic
            return self if obj == 0
            return Sub.new(self,obj)
        end

        def -(obj : Product)
            if (lft = obj.left) == self 
                return lft * (-obj.right + SONE) 
            elsif (rht = obj.right) == self 
                puts (-obj.left + SONE ) * rht
                return (-obj.left + SONE ) * rht
            end
            return Sub.new(self,obj)
        end

        def -(obj) : Symbolic
            return Sub.new(self,obj)
        end

        def - : Symbolic
            return Negative.new(self)
        end

        def opt_sub(obj : Variable) : Symbolic?
            return SZERO if self == obj 
            return nil 
        end

        def *(obj : Variable) : Symbolic
            return Power.new(self,STWO) if self == obj 
            return Product.new(self,obj)
        end

        def *(obj : BinaryOp) : Symbolic
            return obj * self 
        end

        def *(obj : Snumber) : Symbolic
            return obj if obj == 0
            return self if obj == 1
            return Product.new(obj, self)
        end

        def *(obj) : Symbolic
            return Product.new(self,obj)
        end

        def opt_prod(obj : Variable) : Symbolic?
            return Power.new(self,STWO) if self == obj
            return nil 
        end

        def /(obj : Snumber) : Symbolic
            return self if obj == 1
            return PinfinityC if obj == 0
            return Division.new(self,obj)
        end

        def /(obj : Variable) : Symbolic
            return SONE if self == obj 
            return Division.new(self,obj)
        end 

        def /(obj : Product) : Symbolic
            return self / (obj.right / obj.left).as(Symbolic)
        end

        def /(obj : Division) : Symbolic
            return (self * obj.right).as(Symbolic) / obj.left
        end

        def /(obj : Power) : Symbolic
            if obj.left == self
                exp = obj.right - SONE
                return self ** (- exp)
            end
            return Division.new(self,obj)
        end

        def /(obj) : Symbolic
            return Division.new(self,obj)
        end

        def opt_div(obj : Variable) : Symbolic?
            return SONE if self == obj
            nil 
        end

        def **(obj : Snumber) : Symbolic
            return SONE if obj == 0
            return self if obj == 1
            return Power.new(self,obj)
        end

        def **(obj) : Symbolic
            return Power.new(self,obj)
        end

        def diff(obj : Symbolic) : Symbolic
            return SONE if self == obj 
            return SZERO
        end

        def eval(dict : LcHash) : Num
            bytes = @name.to_slice
            tmp   = Internal.lc_hash_fetch(dict,bytes)
            if Internal.test(tmp)
                return num2num(tmp)
            else
                Exec.lc_raise(LcKeyError,"Dictionary does not contain '#{@name}'")
                return 1 
            end
        end

        @[AlwaysInline]
        def to_s(io)
            io << @name 
        end
        
        @[AlwaysInline]
        def to_s
            return @name 
        end

        def ==(obj : Variable)
            return @name == obj.name
        end
        
        def ==(obj)
            false 
        end

        @[AlwaysInline]
        def depend?(obj)
            return self == obj 
        end

        def get_params(ary)
            ary << self unless ary.includes? self
        end

    end

end