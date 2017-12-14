
# Copyright (c) 2017 Massimiliano Dal Mas
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

    struct LcBTrue  < Base
    end

    struct LcBFalse  < Base  
    end

    alias LcBool = (LcBTrue | LcBFalse)    

    def self.buildTrue
    end

    def self.buildFalse
    end

    def self.lc_bool_invert(value : LcBool)
        if value.is_a? LcBTrue
            return lcfalse
        elsif value.is_a? LcBFalse
            return lctrue
        else 
            # internal.raise()
        end
    end

    def self.lc_bool_eq(val1 : LcBool, val2 : LcBool)
        return lctrue if val1 == val2
        return lcfalse
    end

    def self.lc_bool_gr(val1 : LcBool, val2 : LcBool)
        return lctrue if val1 == lctrue && val2 == lcfalse
        return lcfalse
    end 

    def self.lc_bool_sm(val1 : LcBool, val2 : LcBool)
        return lctrue if val1 == lcfalse && val2 == lctrue
        return lcfalse 
    end

    def self.lc_bool_ge(val1 : LcBool, val2 : LcBool)
        return internal.lc_bool_gr(val1,val2)
    end 

    def self.lc_bool_se(val1 : LcBool, val2 : LcBool)
        return internal.lc_bool_sm(val1,val2)
    end

    def self.lc_bool_ne(val1 : LcBool, val2 : LcBool)
        return internal.lc_bool_invert(
            internal.lc_bool_eq(val1,val2)
        )
    end

    def self.lc_bool_and(val1 : LcBool, val2 : LcBool)
        return lctrue if val1 == lctrue && val2 == lctrue
        return lcfalse
    end

    def self.lc_bool_or(val1 : LcBool, val2 : LcBool)
        return lctrue if val1 == lctrue || val2 == lctrue
        return lcfalse 
    end

end