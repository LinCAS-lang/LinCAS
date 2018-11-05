module LinCAS
    class Ary < Internal::LcArray

        # @total_size
        # @size
        # @ptr

        def size
            if @size.is_a? BigInt
                raise Exception.new("(Ary index is a BigInt)")
            end
            return @size.as(IntnumR)
        end

        def self.[]() : Ary
            _self_ = Internal.new_ary_wrapper
            Internal.lc_ary_init(_self_,Internal.build_fake_int(3))
            _self_.size = 0
            return _self_
        end

        def self.new(size : IntnumR) : Ary
            _self_ = Internal.new_ary_wrapper
            Internal.lc_ary_init(_self_,Internal.build_fake_int(size))
            return _self_
        end

        def push(val :  LcVal)
            raise FrozenError.new("Attempted to modify frozen Ary") if frozen?
            Internal.lc_ary_push(self,val)
        end

        def <<(val :  LcVal)
            push(val)
        end

        def pop 
            raise FrozenError.new("Attempted to modify frozen Ary") if frozen?
            Internal.lc_ary_pop(self)
        end

        def [](index : Intnum)
            if index >= @size || index < 0
                raise IndexError.new("index out of bounds (Ary)")
            end
            return @ptr[index]
        end

        def []?(index : Intnum)
            if index >= @size || index < 0
                return Null
            end
            return @ptr[index]
        end

        def [](index : Range)
            beg = (tmp = index.begin) == 0 ? tmp : 0
            if nd  = index.end < @size
                rg = index.exclusve? ? beg...nd : beg..nd 
            else 
                rg = beg...@size 
            end
            tmp = Ary.new 
            rg.each do |i|
                tmp << self[i]
            end
        end

        def []=(index : IntnumR, val :  LcVal)
            raise FrozenError.new("Attempted to modify frozen Ary") if frozen?
            if index < 0
                raise IndexError.new("index out of bounds (Ary)")
            end
            Internal.lc_ary_index_assign(self,Internal.build_fake_int(index),val)
        end

        def shared_copy(from : IntnumR, count : IntnumR)
            if from >= size || from + count > size 
                raise IndexError.new("index out of bounds (Ary)")
            end
            copy      = Internal.new_ary_wrapper
            copy.size = count
            copy.ptr  = @ptr + from
            copy.freeze
            return copy
        end

        def array_copy 
            copy = [] of  LcVal 
            each { |v| copy << v }
            return copy
        end

        def shifted_copy
            shared_copy 1,size - 1
        end

        def each
            size.times do |i|
                yield @ptr[i]
            end
        end

        def each_with_index
            size.times do |i|
                yield @ptr[i], i
            end
        end

        def map!
            raise FrozenError.new("Attempted to modify frozen Ary") if frozen?
            @ptr.map!(size) do |el|
                yield el
            end
        end

        # def map_with_index!
        #    @ptr.map_with_index!(size) do |el,i|
        #        yield el,i
        #    end
        # end

        def to_s(io)
            io << '['
            each_with_index do |el,i|
                io << el.klass.name
                io << ',' unless i == size - 1
            end
            io << ']'
        end

        def to_s
            String.build { |io| to_s(io) }
        end

        def freeze
            @frozen = true
        end

        def defrost
            @frozen = true 
        end

        def frozen?
            @frozen
        end

        def empty?
            size == 0
        end

    end    

end