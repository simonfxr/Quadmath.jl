
libmpfr = ""
for lib in Libdl.dllist()
    if match(r"\blibmpfr\b", lib) !== nothing
        libmpfr = lib
        break
    end
end

cd(joinpath(dirname(@__FILE__), "src"))
run(`make LIBMPFR=$libmpfr`)
if (!ispath("../lib"))
    run(`mkdir ../lib`)
end

run(`mv mpfr_float128.$(Libdl.dlext) ../lib`)

