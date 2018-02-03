
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

    MAX_MATRIX_CAPA = 200 ** 2 


    class Matrix < BaseC
        @ptr  = Pointer(Value).null
        @rows = 0.as(Intnum)
        @cols = 0.as(Intnum)
        @rw_magnitude = true 
        property ptr, rows, cols, rw_magnitude

        @[AlwaysInline]
        def to_s 
            return Internal.lc_matrix_to_s(self)
        end
    end

    macro matrix_ptr(mx)
        {{mx}}.as(Matrix).ptr
    end

    macro set_matrix_rws(mx,rws)
        {{mx}}.as(Matrix).rows = {{rws}}
    end

    macro set_matrix_cls(mx,cls)
        {{mx}}.as(Matrix).cols = {{cls}}
    end

    macro resize_matrix_capa(mx,rws,cls)
        size = {{rws}} * {{cls}}
        if size > MAX_MATRIX_CAPA
            lc_raise(LcArgumentError,"(Max matrix size exceeded)")
            return Null 
        else
            {{mx}}.as(Matrix).ptr = matrix_ptr({{mx}}).realloc(size)
            set_matrix_rws({{mx}},{{rws}})
            set_matrix_cls({{mx}},{{cls}})
        end
    end

    macro set_matrix_to_null(mx,i,j)
        matrix_ptr({{mx}}).map!({{i}} * {{j}}) {Null}
    end
    
    macro set_matrix_index(mx,i,j,value)
        matrix_ptr({{mx}})[{{i}} * matrix_cls({{mx}}) + {{j}}] = {{value}}
    end

    macro matrix_at_index(mx,i,j)
        matrix_ptr({{mx}})[({{i}}) * (matrix_cls({{mx}})) + {{j}}]
    end

    macro matrix_rws(mx)
        {{mx}}.as(Matrix).rows
    end

    macro matrix_cls(mx)
        {{mx}}.as(Matrix).cols
    end

    macro index(r,c,cols)
        (({{r}}) * ({{cols}}) + {{c}})
    end

    macro same_matrix_size(m1,m2)
        ((matrix_rws({{m1}}) == matrix_rws({{m2}})) && 
                       (matrix_cls({{m1}}) == matrix_cls({{m2}})))
    end

    @[AlwaysInline]
    def self.lc_set_matrix_index(matrix : Value, i : Intnum, j : Intnum, value : Value)
        set_matrix_index(matrix,i,j,value)
    end

    def self.build_matrix(rws : Intnum, cls : Intnum)
        matrix = build_matrix 
        resize_matrix_capa(matrix,rws,cls)
        set_matrix_rws(matrix,rws)
        set_matrix_cls(matrix,cls)
        return matrix 
    end

    def self.build_matrix
        matrix = Matrix.new
        matrix.klass = MatrixClass 
        matrix.data  = MatrixClass.data.clone
        return matrix.as(Value)
    end

    matrix_new = LcProc.new do |args|
        next internal.build_matrix
    end

    def self.lc_matrix_init(matrix : Value, rows : Value, cols : Value)
        r = lc_num_to_cr_i(rows)
        return Null unless r 
        c = lc_num_to_cr_i(cols)
        return Null unless c
        resize_matrix_capa(matrix,r,c)
        if Exec.block_given?
            (0...r).each do |i|
                (0...c).each do |j|
                    set_matrix_index(matrix,i,j,Exec.lc_yield(num2int(i),num2int(j)))
                end
            end
        else
            set_matrix_to_null(matrix,r,c)
        end
        return matrix
    end

    matrix_init = LcProc.new do |args|
        next internal.lc_matrix_init(*args.as(T3))
    end

    def self.lc_matrix_to_s(matrix : Value)
        rws = matrix_rws(matrix)
        cls = matrix_cls(matrix)
        str = String.build do |io|
            io << '|'
            (0...rws).each do |i|
                io << ' ' if i > 0
                (0...cls).each do |j|
                    io << (matrix_at_index(matrix,i,j)).to_s
                    io << ',' if (j < cls - 1)
                end
                io << ';' << '\n' if (i < rws - 1)
            end
            io << '|'
        end
        return lc_obj_to_s(matrix) if str.size > STR_MAX_CAPA
        return build_string(str)
    end

    matrix_to_s = LcProc.new do |args|
        next internal.lc_matrix_to_s(*args.as(T1))
    end

    def self.lc_matrix_index(matrix : Value,i : LcRange, j : LcRange)
        r_lower = left(i)
        r_upper = right(i)
        c_lower = left(j)
        c_upper = right(j)
        r_lower,r_upper = r_upper,r_lower if r_upper < r_lower
        c_lower,c_upper = c_upper,c_lower if c_upper < c_lower
        r_upper -= 1 if !inclusive(i) 
        c_upper -= 1 if !inclusive(j)
        c_lower = 0 if c_lower < 0
        r_lower = 0 if r_lower < 0
        rws     = matrix_rws(matrix)
        cls     = matrix_cls(matrix)
        r_upper = rws - 1 if r_upper >= rws
        c_upper = cls - 1 if c_upper >= cls
        tmp    = build_matrix(range_size(i),range_size(j))
        r_size = range_size(j)
        (r_lower..r_upper).each do |r|
            (c_lower..c_upper).each do |c|
                (matrix_ptr(tmp) + index(r - r_lower,c - c_lower,r_size)).copy_from(
                    (matrix_ptr(matrix) + index(r,c,cls)), 1
                )
            end
                
        end
        return tmp
    end

    def self.lc_matrix_index(matrix : Value,i, j)
        if i.is_a? LcRange 
            cls     = matrix_cls(matrix)
            c       = lc_num_to_cr_i(j)
            return Null unless c
            if (c < 0) || (c > cls)
                lc_raise(LcIndexError,"(Index [#{i.to_s},#{c}] out of matrix)")
                return Null 
            end
            r_lower = left(i)
            r_upper = right(i)
            r_lower,r_upper = r_upper,r_lower if r_upper < r_lower
            r_upper -= 1 if !inclusive(i)
            rws     = matrix_rws(matrix) - 1
            r_lower = 0 if r_lower < 0
            r_upper = rws if r_upper > rws
            tmp = build_matrix(range_size(i),c)
            (r_lower..r_upper).each do |r|
                (matrix_ptr(tmp) + index(r - r_lower,0,1)).copy_from(
                    (matrix_ptr(matrix) + index(r,c,cls)), 1
                )
            end
            return tmp
        elsif j.is_a? LcRange
            r   = lc_num_to_cr_i(i)
            return Null unless r
            rws = matrix_rws(matrix)
            if (r < 0) || (r > rws)
                lc_raise(LcIndexError,"(Index [#{r},#{j.to_s}] out of matrix)")
                return Null 
            end
            cls = matrix_cls(matrix)
            c_lower = left(j)
            c_upper = right(j)
            c_lower,c_upper = c_upper,c_lower if c_upper < c_lower
            c_upper -= 1 if !inclusive(j)
            c_lower = 0 if c_lower < 0
            c_upper = cls if c_upper > cls
            tmp = build_matrix(1,range_size(j))
            (c_lower..c_upper).each do |c|
                (matrix_ptr(tmp) + index(0,c - c_lower,range_size(j))).copy_from(
                    (matrix_ptr(matrix) + index(r,c,cls)), 1
                )
            end 
            return tmp
        else 
            r = lc_num_to_cr_i(i)
            return Null unless r 
            c = lc_num_to_cr_i(j)
            return Null unless c 
            if (r < 0) && (c < 0) && (r >= matrix_rws(matrix)) && (c >= matrix_cls(matrix))
                return Null 
            end 
            return matrix_at_index(matrix,r,c)
        end
    end

    matrix_index = LcProc.new do |args|
        next internal.lc_matrix_index(*args.as(T3))
    end

    def self.lc_matrix_set_index(matrix : Value, i : Value,j : Value, value : Value)
        r = lc_num_to_cr_i(i)
        return Null unless r 
        c = lc_num_to_cr_i(j)
        return Null unless c 
        if (r < 0) && (c < 0) && (r >= matrix_rws(matrix)) && (c >= matrix_cls(matrix))
            lc_raise(LcIndexError,"(Index [#{r},#{c}] out of matrix)")
            return Null 
        end
        set_matrix_index(matrix,r,c,value)
        return matrix 
    end

    matrix_set_index = LcProc.new do |args|
        next internal.lc_matrix_set_index(*args.as(T4))
    end

    def self.lc_matrix_sum(m1 : Value, m2 : Value)
        unless m2.is_a? Matrix 
            lc_raise(LcTypeError,"No implicit conversion of #{lc_typeof(m2)} into Matrix")
            return Null 
        end
        if !same_matrix_size(m1,m2)
            lc_raise(LcMathError,"Incompatible matrices for sum")
            return Null
        end
        rws = matrix_rws(m1)
        cls = matrix_cls(m1)
        tmp = build_matrix(rws,cls)
        m1_ptr = matrix_ptr(m1)
        m2_ptr = matrix_ptr(m2)
        matrix_ptr(tmp).map_with_index!(rws * cls) do |c,i|
            value = Exec.lc_call_fun(m1_ptr[i],"+",m2_ptr[i]).as(Value)
            break if Exec.error?
            value
        end
        return tmp 
    end

    matrix_sum = LcProc.new do |args|
        next internal.lc_matrix_sum(*args.as(T2))
    end

    def self.lc_matrix_sub(m1 : Value, m2 : Value)
        unless m2.is_a? Matrix 
            lc_raise(LcTypeError,"No implicit conversion of #{lc_typeof(m2)} into Matrix")
            return Null 
        end
        if !same_matrix_size(m1,m2)
            lc_raise(LcMathError,"Incompatible matrices for difference")
            return Null
        end
        rws = matrix_rws(m1)
        cls = matrix_cls(m1)
        tmp = build_matrix(rws,cls)
        m1_ptr = matrix_ptr(m1)
        m2_ptr = matrix_ptr(m2)
        matrix_ptr(tmp).map_with_index!(rws * cls) do |c,i|
            value = Exec.lc_call_fun(m1_ptr[i],"-",m2_ptr[i]).as(Value)
            break if Exec.error?
            value
        end
        return tmp 
    end

    matrix_sub = LcProc.new do |args|
        next internal.lc_matrix_sub(*args.as(T2))
    end

    def self.lc_matrix_prod(m1 : Value, num : LcNum)
        val = num2num(num)
        cls = matrix_cls(m1)
        rws = matrix_rws(m1)
        tmp = build_matrix(rws,cls)
        ptr = matrix_ptr(m1)
        matrix_ptr(tmp).map_with_index! (rws * cls) do |c,i|
            value = Exec.lc_call_fun(ptr[i],"*",num).as(Value)
            break if Exec.error?
            value
        end
        return tmp 
    end

    def self.lc_matrix_prod(m1 : Value, m2)
        unless m2.is_a? Matrix 
            lc_raise(LcTypeError,"No implicit conversion of #{lc_typeof(m2)} into Matrix")
            return Null 
        end
        rws1 = matrix_rws(m1)
        cls1 = matrix_cls(m1)
        rws2 = matrix_rws(m2)
        cls2 = matrix_cls(m2)
        if cls1 != rws2 
            lc_raise(LcMathError,"Incompatible matrices for product")
            return Null 
        end
        tmp = build_matrix(rws1,cls2)
        (0...rws1).each do |i|
            (0...cls2).each do |j|
                (0...cls1).each do |k|
                    if k == 0
                        value = Exec.lc_call_fun(matrix_at_index(m1,i,k),
                                                        "*",matrix_at_index(m2,k,j)).as(Value)
                        break if Exec.error?
                        set_matrix_index(tmp,i,j,value)
                    else
                        tmp_val = matrix_at_index(tmp,i,j)
                        value = Exec.lc_call_fun(matrix_at_index(m1,i,k),
                                                        "*",matrix_at_index(m2,k,j)).as(Value) 
                        break if Exec.error?
                        value = Exec.lc_call_fun(tmp_val,"+",value).as(Value)
                        break if Exec.error?
                        set_matrix_index(tmp,i,j,value) 
                    end
                end
                break if Exec.error?
            end
            break if Exec.error?
        end
        return tmp
    end

    matrix_prod = LcProc.new do |args|
        next internal.lc_matrix_prod(*args.as(T2))
    end

    def self.lc_matrix_t(mx : Value)
        cls = matrix_cls(mx)
        rws = matrix_rws(mx)
        tmp = build_matrix(cls,rws)
        (0...cls).each do |i|
            (0...rws).each do |j|
                set_matrix_index(tmp,i,j,matrix_at_index(mx,j,i))
            end
        end
        return tmp 
    end

    matrix_t = LcProc.new do |args|
        next internal.lc_matrix_t(*args.as(T1))
    end

    def self.lc_matrix_each(mx : Value)
        rws  = matrix_rws(mx)
        cls  = matrix_cls(mx)
        ptr  = matrix_ptr(mx)
        size = rws * cls
        (0...size).each do |i|
            Exec.lc_yield(ptr[i])
            break if Exec.error?
        end
        return Null 
    end

    matrix_each = LcProc.new do |args|
        next internal.lc_matrix_each(*args.as(T1))
    end

    def self.lc_matrix_map(mx : Value)
        rws  = matrix_rws(mx)
        cls  = matrix_cls(mx)
        tmp  = build_matrix(rws,cls)
        (0...rws).each do |i|
            (0...cls).each do |j|
                value = Exec.lc_yield(matrix_at_index(mx,i,j))
                break if Exec.error?
                set_matrix_index(tmp,i,j,value)
            end
            break if Exec.error?
        end
        return tmp 
    end

    matrix_map = LcProc.new do |args|
        next internal.lc_matrix_map(*args.as(T1))
    end



    MatrixClass = internal.lc_build_class_only("Matrix")
    internal.lc_set_parent_class(MatrixClass,Obj)

    internal.lc_add_static_singleton(MatrixClass,"new",matrix_new,0)
    internal.lc_add_internal(MatrixClass,"init",matrix_init,      2)
    internal.lc_add_internal(MatrixClass,"to_s",matrix_to_s,      0)
    internal.lc_add_internal(MatrixClass,"[]",matrix_index,       2)
    internal.lc_add_internal(MatrixClass,"[]=",matrix_set_index,  3)
    internal.lc_add_internal(MatrixClass,"+",matrix_sum,          1)
    internal.lc_add_internal(MatrixClass,"-",matrix_sub,          1)
    internal.lc_add_internal(MatrixClass,"*",matrix_prod,         1)
    internal.lc_add_internal(MatrixClass,"tr",matrix_t,           0)
    internal.lc_add_internal(MatrixClass,"each",matrix_each,      0)
    internal.lc_add_internal(MatrixClass,"map",matrix_map,        0)
    
end