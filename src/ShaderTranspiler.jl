module ShaderTranspiler

using Libdl
using stc_jll

include("STCLibError.jl")

include("lib_utils.jl")
using .LibSyms

include("Config.jl")
using .Config

#! format: off
public Config
#! format: on
export ConfigHandle, free_config_handle!, set_config_opts!

include("transpile.jl")
include("qual_macros.jl")

#! format: off
public check_abi
#! format: on

function check_abi(print_success::Bool=true)
    lib_abi_ver::UInt8 = ccall((LIBSTC_ABI_VERSION, libstc), UInt8, ())
    pkg_ver = pkgversion(ShaderTranspiler)

    if pkg_ver.major < lib_abi_ver
        error("ABI version of libstc loaded by stc_jll ($lib_abi_ver) is incompatible with the current Pkg major version ($pkg_abi_ver)")
    end

    print_success && println("libstc ABI version and Pkg major version are compatible")
end

function __init__()
    function check_fn_exists(fn::Symbol)
        sym = Libdl.dlsym(handle, fn; throw_error=false)

        if sym === nothing
            error("Couldn't find function named $fn in the stc library acquired from the jll.",
                "This is an unrecoverable internal error in the wrapping logic itself.",
                "It most likely indicates that an FFI breaking C API change in the library was not appropriately updated in ShaderTranspiler.jl")
        end
    end

    handle = Libdl.dlopen(libstc; throw_error=false)
    if handle === nothing
        error("Couldn't open libstc from the path provided by stc_jll, this is an unrecoverable internal error.", false)
    end

    check_fn_exists(LIBSTC_ABI_VERSION)

    if pkgversion(ShaderTranspiler) === nothing
        @warn "Couldn't load ShaderTranspiler's Pkg version at initialization time, ABI compatibility check will be skipped. To perform this check manually, call ShaderTranspiler.check_abi() after initialization."
    else
        check_abi(false)
    end

    for lib_fn in LibSyms._LIB_FN_SYMS
        check_fn_exists(lib_fn)
    end

    Libdl.dlclose(handle)
end

end
