
require "../Test"

include LinCAS::Internal

file "Boolean.cr"

spec "Testing function lc_bool_invert"
test bool_invert do 
    does "!false"
    assert_eq(LcTrue, Internal.lc_bool_invert(LcFalse))
    does "!true"
    assert_eq(LcFalse,Internal.lc_bool_invert(LcTrue))
end

spec "Testing function lc_bool_eq"
test bool_eq do 
    does "true == true"
    assert_eq(LcTrue, Internal.lc_bool_eq(LcTrue,LcTrue))
    does "true == false"
    assert_eq(LcFalse, Internal.lc_bool_eq(LcTrue,LcFalse))
end

spec "Testing function lc_bool_and"
test bool_and do
    does "true && true"
    assert_eq(LcTrue,  Internal.lc_bool_and(LcTrue,LcTrue))
    does "false && true"
    assert_eq(LcFalse, Internal.lc_bool_and(LcFalse,LcTrue))
    does "false && false"
    assert_eq(LcFalse, Internal.lc_bool_and(LcFalse,LcFalse))
end

spec "Testing function lc_bool_or"
test bool_or do 
    does "true || true"
    assert_eq(LcTrue, Internal.lc_bool_or(LcTrue,LcTrue))
    does "false || true"
    assert_eq(LcTrue, Internal.lc_bool_or(LcFalse,LcTrue))
    does "false || false"
    assert_eq(LcFalse,Internal.lc_bool_or(LcFalse,LcFalse))
end