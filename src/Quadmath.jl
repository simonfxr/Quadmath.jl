__precompile__()
module Quadmath

export Float128, Complex256

import Base: (*), +, -, /,  <, <=, ==, ^, convert, cconvert,
          reinterpret, sign_mask, exponent_mask, exponent_one, exponent_half,
          significand_mask,
          promote_rule, widen,
          string, print, show, showcompact, parse,
          acos, acosh, asin, asinh, atan, atanh, cosh, cos,
          exp, expm1, log, log2, log10, log1p, sin, sinh, sqrt, cbrt,
          tan, tanh,
          ceil, floor, trunc, round, fma,
          atan2, copysign, max, min, hypot,
          abs, imag, real, conj, angle, cis,
          eps, realmin, realmax, isinf, isnan, isfinite

import Base.MPFR: ROUNDING_MODE
import SpecialFunctions: erf, erfc,
    besselj, besselj0, besselj1, bessely, bessely0, bessely1, gamma, lgamma
using Compat.MathConstants
import Compat: Sys

@static if Sys.isapple()
    const quadoplib = Symbol("libquadmath.0")
    const libquadmath = Symbol("libquadmath.0")
elseif Sys.isunix()
    const quadoplib = Symbol("libgcc_s.so.1")
    const libquadmath = Symbol("libquadmath.so")
    #const mpfr_float128 = joinpath(dirname(@__FILE__),
    #            "..", "deps", "lib", "mpfr_float128.so")
elseif Sys.iswindows()
    const quadoplib = Symbol("libgcc_s_seh-1.dll")
    const libquadmath = Symbol("libquadmath-0.dll")
end

@static if Sys.isunix()
    # we use this slightly cumbersome definition to ensure that the value is passed
    # on the xmm registers, matching the x86_64 ABI for __float128.
    const Cfloat128 = NTuple{2,VecElement{Float64}}

    struct Float128 <: AbstractFloat
        data::Cfloat128
    end
    Float128(x::Number) = convert(Float128, x)

    const Complex256 = Complex{Float128}

    cconvert(::Type{Cfloat128}, x::Float128) = x.data

    # reinterpret
    function reinterpret(::Type{UInt128}, x::Float128)
        hi = reinterpret(UInt64, x.data[2].value)
        lo = reinterpret(UInt64, x.data[1].value)
        UInt128(hi) << 64 | lo
    end
    function reinterpret(::Type{Float128}, x::UInt128)
        fhi = reinterpret(Float64, (x >> 64) % UInt64)
        flo = reinterpret(Float64, x % UInt64)
        Float128((VecElement(flo), VecElement(fhi)))
    end
    reinterpret(::Type{Unsigned}, x::Float128) = reinterpret(UInt128, x)

    reinterpret(::Type{Int128}, x::Float128) =
        reinterpret(Int128, reinterpret(UInt128, x))
    reinterpret(::Type{Float128}, x::Int128) =
        reinterpret(Float128, reinterpret(UInt128, x))

elseif Sys.iswindows()
    primitive type Float128 128 end
    const Cfloat128 = Float128
end

sign_mask(::Type{Float128}) =        0x8000_0000_0000_0000_0000_0000_0000_0000
exponent_mask(::Type{Float128}) =    0x7fff_0000_0000_0000_0000_0000_0000_0000
exponent_one(::Type{Float128}) =     0x3fff_0000_0000_0000_0000_0000_0000_0000
exponent_half(::Type{Float128}) =    0x3ffe_0000_0000_0000_0000_0000_0000_0000
significand_mask(::Type{Float128}) = 0x0000_ffff_ffff_ffff_ffff_ffff_ffff_ffff

fpinttype(::Type{Float128}) = UInt128

# conversion

## Float64
convert(::Type{Float128}, x::Float64) =
    Float128(ccall((:__extenddftf2, quadoplib), Cfloat128, (Cdouble,), x))
convert(::Type{Float64}, x::Float128) =
    ccall((:__trunctfdf2, quadoplib), Cdouble, (Cfloat128,), x)

convert(::Type{Int32}, x::Float128) =
    ccall((:__fixtfsi, quadoplib), Int32, (Cfloat128,), x)
convert(::Type{Float128}, x::Int32) =
    Float128(ccall((:__floatsitf, quadoplib), Cfloat128, (Int32,), x))

convert(::Type{Float128}, x::UInt32) =
    Float128(ccall((:__floatunsitf, quadoplib), Cfloat128, (UInt32,), x))

convert(::Type{Int64}, x::Float128) =
    ccall((:__fixtfdi, quadoplib), Int64, (Cfloat128,), x)
convert(::Type{Float128}, x::Int64) =
    Float128(ccall((:__floatditf, quadoplib), Cfloat128, (Int64,), x))


#const ROUNDING_MODE = Cint[0] # TODO: CHECK!!!!

function convert(::Type{BigFloat}, x::Float128)
    z = BigFloat()
    res = ccall((:mpfr_set_float128, :libmpfr), Int32,
                (Ptr{BigFloat}, Cfloat128, Int32), Ref(z), x, ROUNDING_MODE[])
    return z
end

convert(::Type{Float128}, x::BigFloat) =
    Float128(ccall((:mpfr_get_float128, :libmpfr), Cfloat128,
                   (Ptr{BigFloat},Int32), Ref(x), ROUNDING_MODE[]))

# comparison

(==)(x::Float128, y::Float128) =
    ccall((:__eqtf2,quadoplib), Cint, (Cfloat128,Cfloat128), x, y) == 0

(<)(x::Float128, y::Float128) =
    ccall((:__letf2,quadoplib), Cint, (Cfloat128,Cfloat128), x, y) == -1

(<=)(x::Float128, y::Float128) =
    ccall((:__letf2,quadoplib), Cint, (Cfloat128,Cfloat128), x, y) <= 0

# arithmetic

(+)(x::Float128, y::Float128) =
    Float128(ccall((:__addtf3,quadoplib), Cfloat128, (Cfloat128,Cfloat128), x, y))
(-)(x::Float128, y::Float128) =
    Float128(ccall((:__subtf3,quadoplib), Cfloat128, (Cfloat128,Cfloat128), x, y))
(*)(x::Float128, y::Float128) =
    Float128(ccall((:__multf3,quadoplib), Cfloat128, (Cfloat128,Cfloat128), x, y))
(/)(x::Float128, y::Float128) =
    Float128(ccall((:__divtf3,quadoplib), Cfloat128, (Cfloat128,Cfloat128), x, y))
(-)(x::Float128) =
    Float128(ccall((:__negtf2,quadoplib), Cfloat128, (Cfloat128,), x))
(^)(x::Float128, y::Float128) =
    Float128(ccall((:powq,libquadmath), Cfloat128, (Cfloat128,Cfloat128), x, y))

# math

## one argument
for f in (:acos, :acosh, :asin, :asinh, :atan, :atanh, :cosh, :cos,
          :erf, :erfc, :exp, :expm1, :log, :log2, :log10, :log1p,
          :sin, :sinh, :sqrt, :cbrt, :tan, :tanh,
          :ceil, :floor, :trunc, :lgamma, )
    @eval function $f(x::Float128)
        Float128(ccall(($(string(f,:q)), libquadmath), Cfloat128,
                       (Cfloat128, ), x))
    end
end
for (f,fc) in (:abs => :fabs,
               :round => :rint,
               :gamma => :tgamma,
               :besselj0 => :j0,
               :besselj1 => :j1,
               :bessely0 => :y0,
               :bessely1 => :y1,)
    @eval function $f(x::Float128)
        Float128(ccall(($(string(fc,:q)), libquadmath), Cfloat128,
                       (Cfloat128, ), x))
    end
end

## two argument
for f in (:atan2, :copysign, :hypot, )
    @eval function $f(x::Float128, y::Float128)
        Float128(ccall(($(string(f,:q)), libquadmath), Cfloat128,
                       (Cfloat128, Cfloat128), x, y))
    end
end

## misc
fma(x::Float128, y::Float128, z::Float128) =
    Float128(ccall((:fmaq,libquadmath), Cfloat128,
                   (Cfloat128, Cfloat128, Cfloat128), x, y, z))

isnan(x::Float128) =
    0 != ccall((:isnanq,libquadmath), Cint, (Cfloat128, ), x)
isinf(x::Float128) =
    0 != ccall((:isinfq,libquadmath), Cint, (Cfloat128, ), x)
isfinite(x::Float128) =
    0 != ccall((:finiteq,libquadmath), Cint, (Cfloat128, ), x)

besselj(n::Cint, x::Float128) =
       Float128(ccall((:jnq, libquadmath), Cfloat128, (Cint, Cfloat128), n, x))
bessely(n::Cint, x::Float128) =
       Float128(ccall((:ynq, libquadmath), Cfloat128, (Cint, Cfloat128), n, x))

eps(::Type{Float128}) = reinterpret(Float128, 0x3f8f0000000000000000000000000000)
realmin(::Type{Float128}) = reinterpret(Float128, 0x00010000000000000000000000000000)
realmax(::Type{Float128}) = reinterpret(Float128, 0x7ffeffffffffffffffffffffffffffff)

for sym in (:π, :e, :γ, :catalan, :φ)
    value = reinterpret(UInt128, convert(Float128, big(eval(sym))))
    @eval convert(::Type{Float128}, ::Irrational{$(Meta.quot(sym))}) = reinterpret(Float128, $value)
end

ldexp(x::Float128, n::Cint) =
    Float128(ccall((:ldexpq, libquadmath), Cfloat128, (Cfloat128, Cint), x, n))
ldexp(x::Float128, n::Integer) =
    ldexp(x, clamp(n, typemin(Cint), typemax(Cint)) % Cint)

function frexp(x::Float128)
    r = Ref{Cint}()
    Float128(ccall((:frexpq, libquadmath), Cfloat128, (Cfloat128, Ptr{Cint}), x, r))
    return x, Int(r[])
end

promote_rule(::Type{Float128}, ::Type{Float16}) = Float128
promote_rule(::Type{Float128}, ::Type{Float32}) = Float128
promote_rule(::Type{Float128}, ::Type{Float64}) = Float128
promote_rule(::Type{Float128}, ::Type{<:Integer}) = Float128


#widen(::Type{Float64}) = Float128
widen(::Type{Float128}) = BigFloat

# TODO: need to do this better
function parse(::Type{Float128}, s::AbstractString)
    Float128(ccall((:strtoflt128, libquadmath), Cfloat128, (Cstring, Ptr{Ptr{Cchar}}), s, C_NULL))
end

function string(x::Float128)
    lng = 64
    buf = Array{UInt8}(lng + 1)
    lng = ccall((:quadmath_snprintf,libquadmath), Cint, (Ptr{UInt8}, Csize_t, Ptr{UInt8}, Cfloat128...), buf, lng + 1, "%.35Qe", x)
    return unsafe_string(pointer(buf), lng)
end

print(io::IO, b::Float128) = print(io, string(b))
show(io::IO, b::Float128) = print(io, string(b))
showcompact(io::IO, b::Float128) = print(io, string(b))

end # module Quadmath
