
# Copyright (c) 2017-2018 Massimiliano Dal Mas
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module LinCAS::Internal

    #$C Matrix
    # A matrix represents a mathematical matrix containing generic values.
    # This allows to make linear operations with matrices containing specific
    # objects representing maths or other scientific datas.
    # 
    # Users must be careful with method aliases: this type has methods
    # which modify the content of a matrix, and others which return a new one.
    # The first ones usually end with `!`, but there are some exceptions
    # like `Matrix#[]=`

    MAX_MATRIX_CAPA = 200 ** 2 


    class Matrix < BaseC
        @ptr  = Pointer( LcVal).null
        @rows = 0.as(IntnumR)
        @cols = 0.as(IntnumR)
        @rw_magnitude = true 
        property ptr, rows, cols, rw_magnitude
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

    macro matrix_check(matrix)
        unless {{matrix}}.is_a? Matrix 
            lc_raise(LcTypeError,"No implicit conversion of #{lc_typeof(m2)} into Matrix")
            return Null 
        end
    end

    @[AlwaysInline]
    def self.lc_set_matrix_index(matrix :  LcVal, i : Intnum, j : Intnum, value :  LcVal)
        set_matrix_index(matrix,i,j,value)
    end

    def self.build_matrix(rws : IntnumR, cls : IntnumR)
        matrix = build_matrix 
        resize_matrix_capa(matrix,rws,cls)
        set_matrix_rws(matrix,rws)
        set_matrix_cls(matrix,cls)
        return matrix 
    end

    def self.build_matrix
        matrix = lincas_obj_alloc Matrix, @@lc_matrix, data: @@lc_matrix.data.clone
        return matrix.as( LcVal)
    end

    def self.lc_matrix_allocate(klass :  LcVal)
        klass  = klass.as(LcClass)
        matrix = lincas_obj_alloc Matrix, klass, data: klass.data.clone 
        return matrix.as( LcVal)
    end 
    
    #$I init
    #$U init(rows,cols)        -> matrix
    #$U init(rows,cols,&block) -> matrix
    # Initializes a matrix instance given the number of rows and columns.
    # If a block is provided, each component will be set to block return
    # value, else `null` will be used.
    # ```coffee
    # new Matrix(2,2)
    # => |null,null;
    #     null,null|
    #
    # new Matrix(2,2) { (i,j) i + j * 2}
    # => |0,2;
    #     1,3|
    # ```

    def self.lc_matrix_init(matrix :  LcVal, rows :  LcVal, cols :  LcVal)
        r = lc_num_to_cr_i(rows,IntD).as(IntD)
        return Null unless r 
        c = lc_num_to_cr_i(cols,IntD).as(IntD)
        return Null unless c
        if r < 0 || c < 0
            lc_raise(LcArgumentError,"Matrices must have a positive number of rows and columns")
            return Null
        end
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

    def self.matrix_to_string(matrix :  LcVal)
        rws    = matrix_rws(matrix)
        cls    = matrix_cls(matrix)
        buffer = string_buffer_new
        buffer_append(buffer,'|')
        (0...rws).each do |i|
            buffer_append(buffer,' ') if i > 0
            (0...cls).each do |j|
                string_buffer_appender(buffer,(matrix_at_index(matrix,i,j)))
                buffer_append(buffer,',') if (j < cls - 1)
            end
            buffer_append_n(buffer,';','\n') if (i < rws - 1)
         end
        buffer_append(buffer,'|')
        buffer_trunc(buffer)
        return buffer
    end

    #$I to_s
    #$U to_s() -> string
    # Converts a matrix into a string. It is already formatted
    # by rows.
    # ```
    # a := |1,2,3;4,5,6|
    # a.to_s() 
    # #=> |1,2,3;
    #      4,5,6|
    # ```

    def self.lc_matrix_to_s(matrix :  LcVal)
        buffer = matrix_to_string(matrix)
        size   = buff_size(buffer)
        if size > STR_MAX_CAPA
            buffer_dispose(buffer)
            return lc_obj_to_s(matrix) 
        end
        return build_string_with_ptr(buff_ptr(buffer),size)
    end

    def self.lc_matrix_index(matrix :  LcVal,i : LcRange, j : LcRange)
        r_lower = r_left(i)
        r_upper = r_right(i)
        c_lower = r_left(j)
        c_upper = r_right(j)
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
        tmp    = build_matrix(IntD.new(range_size(i)),IntD.new(range_size(j))) # TO FIX
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

    #$I []
    #$U m[rows,cols]             -> object
    #$U m[rows,cols_range]       -> matrix
    #$U m[rows_range,cols]       -> matrix
    #$U m[rows_range,cols_range] -> matrix
    # Returns a component of a matrix or a submatrix.
    # Indexes starts from `0`.
    # ```
    # m := |1,2,3; 4,5,6; 7,8,9|
    # m[1,1]       #=> 5
    # m[0,1..2]    #=> |2,3|
    #
    # m[1..2,1]    
    # #=> |5;
    #      8| 
    #
    # m[1..2,1..2]
    # #=> |5,6;
    #      8,9|
    # ```

    def self.lc_matrix_index(matrix :  LcVal,i, j)
        if i.is_a? LcRange 
            cls     = matrix_cls(matrix)
            c       = lc_num_to_cr_i(j,IntD).as(IntD)
            return Null unless c
            if (c < 0) || (c > cls)
                lc_raise(LcIndexError,"(Index [#{i.to_s},#{c}] out of matrix)")
                return Null 
            end
            r_lower = r_left(i)
            r_upper = r_right(i)
            r_lower,r_upper = r_upper,r_lower if r_upper < r_lower
            r_upper -= 1 if !inclusive(i)
            rws     = matrix_rws(matrix) - 1
            r_lower = 0 if r_lower < 0
            r_upper = rws if r_upper > rws
            tmp = build_matrix(range_size(i),1)
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
            c_lower = r_left(j)
            c_upper = r_right(j)
            c_lower,c_upper = c_upper,c_lower if c_upper < c_lower
            c_upper -= 1 if !inclusive(j)
            c_lower = 0 if c_lower < 0
            c_upper = cls if c_upper > cls
            tmp = build_matrix(1,IntD.new(range_size(j))) # TO FIX
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

    #$I []=
    #$U m[row,col] := object
    # It assigns to a component the given value (object).
    #
    # If `row` or `col` is out of bounds, an error will be raised
    # ```
    # m := |1,2; 3,4|
    # m[1,1] := 9
    # #=> |1,2;
    #      3,9|
    #
    # m[2,3] := 9 #=> IndexError: (Index [2,3] out of matrix)
    # ```

    def self.lc_matrix_set_index(matrix :  LcVal, i :  LcVal,j :  LcVal, value :  LcVal)
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

    #$I +
    #$U m + other_matrix -> new_matrix
    # It performs the sum [A] + [B] of two matrices.
    # 
    # If `m` and `other_matrix` do not have the same shape
    # an error will be raised.
    # ```
    # m1 := |1,2,3; 4,5,6|
    # m2 := |1,0,1; 2,0,2|
    # m3 := |6,7; 8,9|
    #
    # m1 + m2
    # #=> |2,2,4;
    #      6,5,8|
    #
    # m1 + m3 #=> MathError: Incompatible matrices for sum
    # ```

    def self.lc_matrix_sum(m1 :  LcVal, m2 :  LcVal)
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
            value = Exec.lc_call_fun(m1_ptr[i],"+",m2_ptr[i]).as( LcVal)
            break if Exec.error?
            value
        end
        return tmp 
    end

    #$I -
    #$U m - other_matrix -> new_matrix
    # It performs the difference [A] - [B] of two matrices.
    # 
    # If `m` and `other_matrix` do not have the same shape
    # an error will be raised.
    # ```
    # m1 := |1,2,3; 4,5,6|
    # m2 := |1,0,1; 2,0,2|
    # m3 := |6,7; 8,9|
    #
    # m1 - m2
    # #=> |0,2,2;
    #      2,5,4|
    #
    # m1 - m3 #=> MathError: Incompatible matrices for difference
    # ```

    def self.lc_matrix_sub(m1 :  LcVal, m2 :  LcVal)
        matrix_check(m2)
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
            value = Exec.lc_call_fun(m1_ptr[i],"-",m2_ptr[i]).as( LcVal)
            break if Exec.error?
            value
        end
        return tmp 
    end

    #$I *
    #$U m * number       -> new_matrix
    #$U m * other_matrix -> new_matrix
    # If the argument is a number, a new matrix will be returned
    # with each component set to `m[i,j] * number`.
    #
    # If the argument is a matrix, a matricial product is performed.
    # If matrices are incompatible, an error is raised
    # ```
    # m1 := |1,2,3; 4,5,6|
    # m2 := |1,5; 1,6; 0,2|
    # m3 := |2,7; 9,8|
    #
    # m1 + 3
    # #=> |3,6,9;
    #      12,15,18|
    # m1 * m2
    # #=> |3,23;
    #      9,62|
    #
    # m1 * m3 #=> MathError: Incompatible matrices for product
    # ```

    def self.lc_matrix_prod(m1 :  LcVal, num : LcNum)
        val = num2num(num)
        cls = matrix_cls(m1)
        rws = matrix_rws(m1)
        tmp = build_matrix(rws,cls)
        ptr = matrix_ptr(m1)
        matrix_ptr(tmp).map_with_index! (rws * cls) do |c,i|
            value = Exec.lc_call_fun(ptr[i],"*",num).as( LcVal)
            break if Exec.error?
            value
        end
        return tmp 
    end

    def self.lc_matrix_prod(m1 :  LcVal, m2)
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
                                                        "*",matrix_at_index(m2,k,j)).as( LcVal)
                        break if Exec.error?
                        set_matrix_index(tmp,i,j,value)
                    else
                        tmp_val = matrix_at_index(tmp,i,j)
                        value = Exec.lc_call_fun(matrix_at_index(m1,i,k),
                                                        "*",matrix_at_index(m2,k,j)).as( LcVal) 
                        break if Exec.error?
                        value = Exec.lc_call_fun(tmp_val,"+",value).as( LcVal)
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

    #$I tr
    #$U m.tr() -> new_matrix
    # It transposes a matrix
    # ```
    # m2 := |1,5; 1,6; 0,2|
    # m2.tr()
    # #=> |1,1,0;
    #      5,6,2|
    # ```

    def self.lc_matrix_t(mx :  LcVal)
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

    #$I each
    #$U m.each(&block) -> m
    # Iterates over each component of a matrix
    # passing it to the given block
    # ```
    # m := |1,2; 3,4|
    # m.each() { (v) printl v }
    # #=>
    # 1
    # 2
    # 3
    # 4
    # ```

    def self.lc_matrix_each(mx :  LcVal)
        rws  = matrix_rws(mx)
        cls  = matrix_cls(mx)
        ptr  = matrix_ptr(mx)
        size = rws * cls
        (0...size).each do |i|
            Exec.lc_yield(ptr[i])
            break if Exec.error?
        end
        return mx
    end

    def self.lc_matrix_map(mx :  LcVal)
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

    def self.lc_matrix_o_map(mx :  LcVal)
        size = matrix_rws(mx) * matrix_cls(mx)
        ptr  = matrix_ptr(mx)
        ptr.map!(size) do |elem|
            value = Exec.lc_yield(elem).as( LcVal)
            break if Exec.error?
            value
        end
        return mx 
    end

    def self.lc_matrix_each_with_index(mx :  LcVal)
        rws  = matrix_rws(mx)
        cls  = matrix_cls(mx)
        rws.times do |i|
            cls.times do |j|
                Exec.lc_yield(matrix_at_index(mx,i,j),num2int(i),num2int(j))
                break if Exec.error?
            end
            break if Exec.error?
        end
        return Null 
    end

    def self.lc_matrix_map_with_index(mx :  LcVal)
        rws  = matrix_rws(mx)
        cls  = matrix_cls(mx)
        tmp = build_matrix(rws,cls)
        rws.times do |i|
            cls.times do |j|
                value = Exec.lc_yield(matrix_at_index(mx,i,j),num2int(i),num2int(j)).as( LcVal)
                break if Exec.error?
                set_matrix_index(tmp,i,j,value)
            end
            break if Exec.error?
        end
        return tmp 
    end

    def self.lc_matrix_o_map_with_index(mx :  LcVal)
        rws  = matrix_rws(mx)
        cls  = matrix_cls(mx)
        rws.times do |i|
            cls.times do |j|
                value = Exec.lc_yield(matrix_at_index(mx,i,j),num2int(i),num2int(j)).as( LcVal)
                break if Exec.error?
                set_matrix_index(mx,i,j,value)
            end
            break if Exec.error?
        end
        return mx 
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

    def self.lc_matrix_swap_rws(mx :  LcVal, r1 :  LcVal, r2 :  LcVal)
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

    def self.lc_matrix_swap_cls(mx :  LcVal, c1 :  LcVal, c2 :  LcVal)
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

    def self.lc_matrix_clone(mx :  LcVal)
        rws = matrix_rws(mx)
        cls = matrix_cls(mx)
        tmp = build_matrix(rws,cls)
        matrix_ptr(tmp).copy_from(matrix_ptr(mx),rws * cls)
        return tmp 
    end

    private def self.lc_transfer_data(mx :  LcVal*, ptr : Floatnum*, count : Intnum)   
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

    def self.lc_matrix_det(mx :  LcVal)
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


    def self.lc_matrix_lu(mx :  LcVal)
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

    private def self.matrix_id(size : IntnumR)
        tmp = build_matrix(size,size)
        size.times do |i|
            size.times do |j|
                value = (i == j) ? num2int(1) : num2int(0)
                set_matrix_index(tmp,i,j,value)
            end
        end
        return tmp
    end

    @[AlwaysInline]
    def self.lc_matrix_id(size : LcVal)
        return lc_matrix_id(nil,size)
    end

    def self.lc_matrix_id(klass,size :  LcVal)
        rws = lc_num_to_cr_i(size, Int64).as(Int64)
        return Null unless rws 
        if rws < 0
            lc_raise(LcArgumentError,"(Negative matrix size)")
            return Null 
        end 
        return matrix_id(rws) 
    end

    @[AlwaysInline]
    def self.lc_matrix_size(mx : LcVal)
        rws = matrix_rws(mx)
        cls = matrix_cls(mx)
        return tuple2array(num2int(rws),num2int(cls))
    end

    def self.lc_matrix_max(mx :  LcVal)
        rws    = matrix_rws(mx)
        cls    = matrix_cls(mx)
        ptr    = matrix_ptr(mx)
        length = rws * cls
        if length > 0
            tmp    = Pointer( LcVal).malloc(length)
            tmp.copy_from(ptr,length)
            internal_ary_sort(tmp,length)
            value = tmp[length - 1]
            tmp = tmp.realloc(0)
            return value 
        end 
        return Null 
    end

    def self.lc_matrix_min(mx :  LcVal)
        rws    = matrix_rws(mx)
        cls    = matrix_cls(mx)
        ptr    = matrix_ptr(mx)
        length = rws * cls
        if length > 0
            tmp    = Pointer( LcVal).malloc(length)
            tmp.copy_from(ptr,length)
            internal_ary_sort(tmp,length)
            value = tmp[0]
            tmp = tmp.realloc(0)
            return value 
        end 
        return Null 
    end

    def self.lc_matrix_eq(mx :  LcVal, mx2 :  LcVal)
        return lcfalse unless mx2.is_a? Matrix
        return lcfalse unless same_matrix_size(mx,mx2)
        rws = matrix_rws(mx)
        cls = matrix_cls(mx)
        rws.times do |i|
            cls.times do |j|
                return lcfalse unless fast_compare(matrix_at_index(mx,i,j),matrix_at_index(mx2,i,j))
            end
        end
        return lctrue
    end


    def self.init_matrix
        @@lc_matrix = internal.lc_build_internal_class("Matrix")
        define_allocator(@@lc_matrix,lc_matrix_allocate)

        add_static_method(@@lc_matrix,"identity",lc_matrix_id,      1)
        add_method(@@lc_matrix,"init",lc_matrix_init,      2)
        add_method(@@lc_matrix,"to_s",lc_matrix_to_s,      0)
        add_method(@@lc_matrix,"==",lc_matrix_eq,          1)
        add_method(@@lc_matrix,"[]",lc_matrix_index,       2)
        add_method(@@lc_matrix,"[]=",lc_matrix_set_index,  3)
        add_method(@@lc_matrix,"+",lc_matrix_sum,          1)
        add_method(@@lc_matrix,"-",lc_matrix_sub,          1)
        add_method(@@lc_matrix,"*",lc_matrix_prod,         1)
        add_method(@@lc_matrix,"tr",lc_matrix_t,           0)
        add_method(@@lc_matrix,"det",lc_matrix_det,        0)
        add_method(@@lc_matrix,"lu",lc_matrix_lu,          0)
        add_method(@@lc_matrix,"clone",lc_matrix_clone,    0)
        add_method(@@lc_matrix,"each",lc_matrix_each,      0)
        add_method(@@lc_matrix,"map",lc_matrix_map,        0)
        add_method(@@lc_matrix,"map!",lc_matrix_o_map,     0)
        add_method(@@lc_matrix,"size",lc_matrix_size,      0)
        alias_method_str(@@lc_matrix,"size","shape"              )

        matrix_rws_ = LcProc.new do |args|
            mx  = args.as(T1)[0]
            next num2int(matrix_rws(mx))
        end
    
        matrix_cls_ = LcProc.new do |args|
            mx  = args.as(T1)[0]
            next num2int(matrix_cls(mx))
        end

        lc_add_internal(@@lc_matrix,"rows",matrix_rws_,         0)
        lc_add_internal(@@lc_matrix,"cols",matrix_cls_,         0)
        add_method(@@lc_matrix,"max",lc_matrix_max,        0)
        add_method(@@lc_matrix,"min",lc_matrix_min,        0)
        add_method(@@lc_matrix,"each_with_index",lc_matrix_each_with_index,   0)
        add_method(@@lc_matrix,"map_with_index",lc_matrix_map_with_index,     0)
        add_method(@@lc_matrix,"map_with_index!",lc_matrix_o_map_with_index,  0)
        add_method(@@lc_matrix,"swap_rows",lc_matrix_swap_rws,                2)
        add_method(@@lc_matrix,"swap_cols",lc_matrix_swap_cls,                2)
    end

end
