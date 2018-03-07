
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
            return Internal.matrix_to_string(self)
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

    macro matrix_squared(mx)
        ((matrix_rws({{mx}})) == (matrix_cls({{mx}})))
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

    def self.matrix_to_string(matrix : Value)
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
        return str 
    end

    def self.lc_matrix_to_s(matrix : Value)
        str = matrix_to_string(matrix)
        return lc_obj_to_s(matrix) if str.size > STR_MAX_CAPA
        return build_string(str)
    ensure 
        GC.free(Box.box(str))
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
            if ((r < 0) || (c < 0)) || ((r >= matrix_rws(matrix)) || (c >= matrix_cls(matrix)))
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

    def self.lc_matrix_o_map(mx : Value)
        size = matrix_rws(mx) * matrix_cls(mx)
        ptr  = matrix_ptr(mx)
        ptr.map!(size) do |elem|
            value = Exec.lc_yield(elem).as(Value)
            break if Exec.error?
            value
        end
        return mx 
    end

    matrix_o_map = LcProc.new do |args|
        next internal.lc_matrix_o_map(*args.as(T1))
    end

    def self.lc_matrix_each_with_index(mx : Value)
        rws  = matrix_rws(mx)
        cls  = matrix_cls(mx)
        rws.times do |i|
            cls.times do |j|
                Exec.lc_yield(matrix_at_index(mx,i,j),num2int(i),num2int(j))
                break if Exec.error?
            end
            break if Exec.error
        end
        return Null 
    end

    matrix_each_with_index = LcProc.new do |args|
       next internal.lc_matrix_map_with_index(*args.as(T1))
    end

    def self.lc_matrix_map_with_index(mx : Value)
        rws  = matrix_rws(mx)
        cls  = matrix_cls(mx)
        tmp = build_matrix(rws,cls)
        rws.times do |i|
            cls.times do |j|
                value = Exec.lc_yield(matrix_at_index(mx,i,j),num2int(i),num2int(j)).as(Value)
                break if Exec.error?
                set_matrix_index(tmp,i,j,value)
            end
            break if Exec.error?
        end
        return tmp 
    end

    matrix_map_with_index = LcProc.new do |args|
        next internal.lc_matrix_map_with_index(*args.as(T1))
    end

    def self.lc_matrix_o_map_with_index(mx : Value)
        rws  = matrix_rws(mx)
        cls  = matrix_cls(mx)
        rws.times do |i|
            cls.times do |j|
                value = Exec.lc_yield(matrix_at_index(mx,i,j),num2int(i),num2int(j)).as(Value)
                break if Exec.error?
                set_matrix_index(mx,i,j,value)
            end
            break if Exec.error?
        end
        return mx 
    end

    matrix_o_map_with_index = LcProc.new do |args|
        next internal.lc_matrix_o_map_with_index(*args.as(T1))
    end

    private def self.mx_swap_rws(ptr : Pointer,r1 : Intnum, r2 : Intnum, cls : Intnum)
        cls.times do |j|
            ptr.swap(index(r1,j,cls),index(r2,j,cls))
        end
    end

    private def self.mx_swap_cls(ptr : Pointer, c1 : Intnum, c2 : Intnum, rws : Intnum, cls : Intnum)
        rws.times do |i|
            ptr.swap(index(i,c1,cls),index(i,c2,cls))
        end
    end

    def self.lc_matrix_swap_rws(mx : Value, r1 : Value, r2 : Value)
        r1_val = lc_num_to_cr_i(r1)
        return Null unless r1_val
        r2_val = lc_num_to_cr_i(r2)
        return Null unless r2_val
        rws = matrix_rws(mx)
        if (r1_val < 0) || (r2_val < 0) || (r1_val >= rws) || (r2_val >= rws)
            lc_raise(LcIndexError,"(Indexes out of matrix)")
            return Null 
        end
        cls = matrix_cls(mx)
        ptr = matrix_ptr(mx)
        mx_swap_rws(ptr,r1_val,r2_val,cls)
        return mx
    end

    matrix_swap_rws = LcProc.new do |args|
        next internal.lc_matrix_swap_rws(*args.as(T3))
    end

    def self.lc_matrix_swap_cls(mx : Value, c1 : Value, c2 : Value)
        c1_val = lc_num_to_cr_i(c1)
        return Null unless c1_val
        c2_val = lc_num_to_cr_i(c2)
        return Null unless c2_val
        cls = matrix_cls(mx)
        if (c1_val < 0) || (c2_val < 0) || (c1_val >= cls) || (c2_val >= cls)
            lc_raise(LcIndexError,"(Indexes out of matrix)")
            return Null 
        end
        rws = matrix_rws(mx)
        ptr = matrix_ptr(mx)
        rws.times do |i|
            ptr.swap(index(i,c1_val,cls),index(i,c2_val,cls))
        end
        return mx 
    end 

    matrix_swap_cls = LcProc.new do |args|
        next internal.lc_matrix_swap_cls(*args.as(T3))
    end 

    def self.lc_matrix_clone(mx : Value)
        rws = matrix_rws(mx)
        cls = matrix_cls(mx)
        tmp = build_matrix(rws,cls)
        matrix_ptr(tmp).copy_from(matrix_ptr(mx),rws * cls)
        return tmp 
    end

    matrix_clone = LcProc.new do |args|
        next internal.lc_matrix_clone(*args.as(T1))
    end

    private def self.lc_transfer_data(mx : Value*, ptr : Floatnum*, count : Intnum)   
        success = true  
        ptr.map_with_index!(count) do |c,i|
            num = lc_num_to_cr_f(mx[i])
            unless num 
                success = false 
                break 
            end
            num.as(Floatnum) 
        end
        return 1 if success 
        return nil
    end

    def self.lc_matrix_det(mx : Value)
        unless matrix_squared(mx)
            lc_raise(LcMathError,"(Non-squared matrix for determinant)")
            return Null 
        end 
        rws     = matrix_rws(mx)
        swap_c  = 0
        det     = 1
        tmp     = Pointer(Floatnum).malloc(rws ** 2)
        return Null unless lc_transfer_data(matrix_ptr(mx),tmp,rws ** 2)
        rws.times do |i|
            max_at = i
            (i...rws).each do |m|
                if tmp[index(m,i,rws)].abs > tmp[index(max_at,i,rws)].abs
                    max_at = m 
                end
            end
            unless max_at == i 
                mx_swap_rws(tmp,i,max_at,rws)
                swap_c += 1
            end 
            ((i+1)...rws).each do |r|
                x_val = tmp[index(i,i,rws)]
                alpha = (x_val != 0) ? (tmp[index(r,i,rws)] / x_val) : 0
                ((i+1)...rws).each do |c|
                    tmp[index(r,c,rws)] -= alpha * tmp[index(i,c,rws)]
                end
            end
            det *= tmp[index(i,i,rws)]
        end
        det *= ((-1) ** swap_c)
        tmp = tmp.realloc(0)
        return num2float(0.0) if det.abs == 0
        return num2float(det.to_f.as(Floatnum)) 
    end

    matrix_det = LcProc.new do |args|
        next internal.lc_matrix_det(*args.as(T1))
    end


    def self.lc_matrix_lu(mx : Value)
        unless matrix_squared(mx)
            lc_raise(LcMathError,"(Non-squared matrix for LU reduction)")
            return Null 
        end 
        rws     = matrix_rws(mx)
        tmp     = Pointer(Floatnum).malloc(rws ** 2)
        id      = matrix_id(rws)
        return Null unless lc_transfer_data(matrix_ptr(mx),tmp,rws ** 2)
        rws.times do |i|
            max_at = i
            (i...rws).each do |m|
                if tmp[index(m,i,rws)].abs > tmp[index(max_at,i,rws)].abs
                    max_at = m 
                end
            end
            unless max_at == i 
                mx_swap_rws(tmp,i,max_at,rws)
                mx_swap_cls(matrix_ptr(id),i,max_at,rws,rws)
            end 
            ((i+1)...rws).each do |r|
                x_val = tmp[index(i,i,rws)]
                alpha = (x_val != 0) ? (tmp[index(r,i,rws)] / x_val) : 0.0
                tmp[index(r,i,rws)] = alpha.as(Floatnum)
                ((i+1)...rws).each do |c|
                    tmp[index(r,c,rws)] -= alpha * tmp[index(i,c,rws)]
                end
            end
        end
        l = build_matrix(rws,rws)
        u = build_matrix(rws,rws)
        rws.times do |i|
            rws.times do |j|
                if i > j
                    set_matrix_index(l,i,j,num2float(tmp[index(i,j,rws)].to_f))
                    set_matrix_index(u,i,j,num2int(0))
                else
                    if i == j
                        set_matrix_index(l,i,j,num2int(1))
                    else
                        set_matrix_index(l,i,j,num2int(0))
                    end 
                    set_matrix_index(u,i,j,num2float(tmp[index(i,j,rws)].to_f))
                end
            end
        end
        l = lc_matrix_prod(id,l)
        tmp = tmp.realloc(0)
        return tuple2array(l,u)
    end

    private def self.print_mx(mx : Floatnum*, rws : Intnum)
        rws.times do |i|
            rws.times do |j|
                print mx[index(i,j,rws)].round 
                print ',' unless j == rws - 1
            end
            puts ';'
        end
        puts
    end

    matrix_lu = LcProc.new do |args|
        next internal.lc_matrix_lu(*args.as(T1))
    end

    private def self.matrix_id(size : Intnum)
        tmp = build_matrix(size,size)
        size.times do |i|
            size.times do |j|
                value = (i == j) ? num2int(1) : num2int(0)
                set_matrix_index(tmp,i,j,value)
            end
        end
        return tmp
    end

    def self.lc_matrix_id(size : Value)
        rws = lc_num_to_cr_i(size)
        return Null unless rws 
        if rws < 0
            lc_raise(LcArgumentError,"(Negative matrix size)")
            return Null 
        end 
        return matrix_id(rws) 
    end

    matrix_identity = LcProc.new do |args|
        size = args.as(T2)[1]
        next internal.lc_matrix_id(size)
    end

    matrix_size = LcProc.new do |args|
        mx  = args.as(T1)[0]
        rws = matrix_rws(mx)
        cls = matrix_cls(mx)
        next tuple2array(num2int(rws),num2int(cls))
    end

    matrix_rws_ = LcProc.new do |args|
        mx  = args.as(T1)[0]
        next num2int(matrix_rws(mx))
    end

    matrix_cls_ = LcProc.new do |args|
        mx  = args.as(T1)[0]
        next num2int(matrix_cls(mx))
    end

    def self.lc_matrix_max(mx : Value)
        rws    = matrix_rws(mx)
        cls    = matrix_cls(mx)
        ptr    = matrix_ptr(mx)
        length = rws * cls
        if length > 0
            tmp    = Pointer(Value).malloc(length)
            tmp.copy_from(ptr,length)
            internal_ary_sort(tmp,length)
            value = tmp[length - 1]
            tmp = tmp.realloc(0)
            return value 
        end 
        return Null 
    end

    matrix_max = LcProc.new do |args|
        next internal.lc_matrix_max(*args.as(T1))
    end

    def self.lc_matrix_min(mx : Value)
        rws    = matrix_rws(mx)
        cls    = matrix_cls(mx)
        ptr    = matrix_ptr(mx)
        length = rws * cls
        if length > 0
            tmp    = Pointer(Value).malloc(length)
            tmp.copy_from(ptr,length)
            internal_ary_sort(tmp,length)
            value = tmp[0]
            tmp = tmp.realloc(0)
            return value 
        end 
        return Null 
    end

    matrix_min = LcProc.new do |args|
        next internal.lc_matrix_min(*args.as(T1))
    end


    MatrixClass = internal.lc_build_class_only("Matrix")
    internal.lc_set_parent_class(MatrixClass,Obj)

    internal.lc_add_static_singleton(MatrixClass,"new",matrix_new,0)
    internal.lc_add_static(MatrixClass,"identity",matrix_identity,1)
    internal.lc_add_internal(MatrixClass,"init",matrix_init,      2)
    internal.lc_add_internal(MatrixClass,"to_s",matrix_to_s,      0)
    internal.lc_add_internal(MatrixClass,"[]",matrix_index,       2)
    internal.lc_add_internal(MatrixClass,"[]=",matrix_set_index,  3)
    internal.lc_add_internal(MatrixClass,"+",matrix_sum,          1)
    internal.lc_add_internal(MatrixClass,"-",matrix_sub,          1)
    internal.lc_add_internal(MatrixClass,"*",matrix_prod,         1)
    internal.lc_add_internal(MatrixClass,"tr",matrix_t,           0)
    internal.lc_add_internal(MatrixClass,"det",matrix_det,        0)
    internal.lc_add_internal(MatrixClass,"lu",matrix_lu,          0)
    internal.lc_add_internal(MatrixClass,"clone",matrix_clone,    0)
    internal.lc_add_internal(MatrixClass,"each",matrix_each,      0)
    internal.lc_add_internal(MatrixClass,"map",matrix_map,        0)
    internal.lc_add_internal(MatrixClass,"map!",matrix_o_map,     0)
    internal.lc_add_internal(MatrixClass,"size",matrix_size,      0)
    internal.lc_add_internal(MatrixClass,"length",matrix_size,    0)
    internal.lc_add_internal(MatrixClass,"rows",matrix_rws_,      0)
    internal.lc_add_internal(MatrixClass,"cols",matrix_cls_,      0)
    internal.lc_add_internal(MatrixClass,"max",matrix_max,        0)
    internal.lc_add_internal(MatrixClass,"min",matrix_min,        0)
    internal.lc_add_internal(MatrixClass,"each_with_index",matrix_each_with_index,   0)
    internal.lc_add_internal(MatrixClass,"map_with_index",matrix_map_with_index,     0)
    internal.lc_add_internal(MatrixClass,"map_with_index!",matrix_o_map_with_index,  0)
    internal.lc_add_internal(MatrixClass,"swap_rows",matrix_swap_rws,                2)
    internal.lc_add_internal(MatrixClass,"swap_cols",matrix_swap_cls,                2)

end