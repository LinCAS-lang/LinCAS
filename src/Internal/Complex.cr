
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

    struct LcCmx < LcNum
        @cmx   = uninitialized LibComplex::Gls_cpx
        @alloc = false
        property cmx, alloc 
    end

    macro complex_is_alloc(cpx)
        lc_cast({{cpx}},LcCmx).alloc = true 
    end

    macro complex_allocated?(cpx)
        lc_cast({{cpx}},LcCmx).alloc
    end

    macro set_complex(cpx,cmx)
        lc_cast({{cpx}},LcCmx).cmx = {{cmx}}
        complex_is_alloc({{cpx}})
    end

    def self.complex_allocate
        cmx        = LcCmx.new
        cmx.klass  = ComplexClass
        cmx.data   = ComplexClass.data.clone 
        cmx.id     = cmx.object_id
        lc_obj_freeze(cmx)
        return lc_cast(cmx.Value)
    end

    def self.build_complex(cmx : LibComplex::Gls_cpx)
        tmp = complex_allocate
        set_complex(tmp,cmx)
        return tmp 
    end

    def self.lc_complex_rect(klass : Value, real : Value, img : Value)
        nums = float2cr(real,img)
        return Null unless nums 
        real,img = nums 
        cpx      = LibComplex.gsl_complex_rect(real,img)
        return build_complex(cpx)
    end

    complex_rect = LcProc.new do |args|
        next lc_complex_rect(*lc_cast(args,T3))
    end

    def self.lc_complex_polar(cmx : Value, r : Value, th : Value)
        nums = float2cr(real,img)
        return Null unless nums 
        real,img = nums 
        cpx      = LibComplex.gsl_complex_polar(r,th)
        return build_complex(cpx)
    end

    complex_polar = LcProc.new do |args|
        next lc_complex_polar(*lc_cast(args,T3))
    end


    ComplexClass = lc_build_internal_klass("Complex",NumClass)
    lc_undef_allocator(ComplexClass)

    lc_add_static(ComplexClass,"rect",complex_rect,         2)
    lc_add_static(ComplexClass,"polar",complex_polar,       2)

end