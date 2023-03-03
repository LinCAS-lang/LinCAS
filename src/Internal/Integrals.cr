
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

    macro dict_set(dict,key,value)
        lc_hash_set_index({{dict}},{{key}},{{value}})
    end

    @[AlwaysInline]
    private def self.create_dict(param :  LcVal, beg :  LcVal)
        hash = build_hash
        lc_hash_set_index(hash,param,beg)
        return lc_cast(hash,LcHash)
    end

    # TODO: this methods is affected by computation issues and assumes the 
    # 4th derivative is continue. This provides sometimes a too low number of
    # intervals which does not ensure a precision of 10 ^ -8
    #
    private def self.simpson_intervals(f : Symbolic, a :  LcVal, b :  LcVal)
        params   = [] of Variable
        f.get_params(params)
        param = build_string(params[0].name)
        tmp   = params[0]
        4.times do 
            f = f.diff(tmp)
        end
        return 1000  if f == 0
        dict = create_dict(build_string(param),a)
        max  = f.eval(dict)
        dict_set(dict,param,b)
        if (tmp = f.eval(dict)) > max 
            max = tmp 
        end
        max = max.round(0).to_i + 10
        av  = lc_num_to_cr_f(a).as(Floatnum)
        bv  = lc_num_to_cr_f(b).as(Floatnum)
        n   = Math.sqrt(Math.sqrt(max * (bv - av) / (180 * 10E-9))).round(0).to_i
        p n
        return n + 1 if n.odd?
        return n
    end

    # TODO: method optimization. This methods uses LinCAS hashes as
    # dictionary, but passing to f a Crystal hash would spare LinCAS object
    # allocation such as strings (and numbers)
    #
    private def self.simpson(f : Symbolic,a :  LcVal, b :  LcVal)
        params   = [] of Variable
        f.get_params(params)
        if params.size > 1
            lc_raise(lc_arg_err,"Function must contain only one variable (#{params.size} given)")
            return Float64::NAN 
        end
        param     = build_string(params[0].name)
        dict      = create_dict(param,a)
        an        = lc_num_to_cr_f(a).as(Floatnum)
        bn        = lc_num_to_cr_f(b).as(Floatnum)
        intervals = simpson_intervals(f,a,b)
        hs        = (bn - an) / (intervals * 2.0)
        intSA     = 0
        intSB     = 0
        fa        = f.eval(dict)
        dict_set(dict,param,b)
        fb        = f.eval(dict)
        dict_set(dict,param,num_auto(an + hs))
        intSB += f.eval(dict)
        (1...intervals).each do |i|
            xa = an + (2 * i) * hs
            dict_set(dict,param,num_auto(xa))
            intSA += f.eval(dict)
            xb = an + (2 * i + 1) * hs
            dict_set(dict,param,num_auto(xb))
            intSB += f.eval(dict)
        end
        return  hs / 3.0 * (fa + fb + 2 * intSA + 4 * intSB)
    end

end