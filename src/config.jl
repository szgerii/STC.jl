module Config

export ConfigHandle
export free_config_handle!
export set_err_dump_verbosity!

using stc_jll
using ..ShaderTranspiler: CFG_OPTIONS
using ..ShaderTranspiler.LibSyms

"""
RAII-esque type that wraps a low-level config handle
"""
mutable struct ConfigHandle
    ptr::Ptr{Cvoid}

    function ConfigHandle()
        ptr = _create_config_handle()
        ptr == C_NULL && error("Couldn't obtain a config handle through libstc")

        handle = new(ptr)
        finalizer(free_config_handle!, handle)

        return handle
    end

    function ConfigHandle(ptr::Ptr{Cvoid})
        ptr == C_NULL && error("Cannot create a ConfigHandle that wraps a null pointer")

        return new(ptr)
    end
end

export ERR_DUMP_NONE, ERR_DUMP_PARTIAL, ERR_DUMP_VERBOSE

const ERR_DUMP_NONE::UInt8 = 0
const ERR_DUMP_PARTIAL::UInt8 = 1
const ERR_DUMP_VERBOSE::UInt8 = 2

"""
    set_err_dump_dump_verbosity!(handle::ConfigHandle, value::UInt8)

Wrapper for modifyig the err_dump_verbosity transpiler option from Julia.

`value` must be one of:
- `0` -> None
- `1` -> Partial
- `2` -> Verbose

The `ERR_DUMP_` constants are provided as helpers.

Throws `DomainError` if value is not one of the above options.
"""
function set_err_dump_verbosity!(ptr::Ptr{Cvoid}, value::UInt8)
    value >= 0x03 && throw(DomainError(value, "Value cannot be greater than 3, excepted values are:\n0 -> None\n1 -> Partial\n2 -> Verbose"))

    if ptr != C_NULL
        ccall((LIBSTC_SET_ERR_DUMP_VERBOSITY, libstc), Cvoid, (Ptr{Cvoid}, UInt8), ptr, value)
    end
end

set_err_dump_verbosity!(handle::ConfigHandle, value::UInt8) = set_err_dump_verbosity!(handle.ptr, value)

"""
    create_config_handle()::Ptr{Cvoid}

Low-level endpoint for acquiring a new configuration handle from the stc library. External use is discouraged in favor of using `ConfigHandle`-s.

Throws `STCLibError` on failure, which indicates the library returned a null pointer.
"""
function _create_config_handle()::Ptr{Cvoid}
    ptr = ccall((LIBSTC_CREATE_CFG, libstc), Ptr{Cvoid}, ())

    if ptr == C_NULL
        throw(STCLibError(LIBSTC_CREATE_CFG, "Couldn't create configuration handle."))
    end

    return ptr
end


"""
    free_config_handle!(handle::ConfigHandle)

Frees a configuration handle and makes it point to `C_NULL`. If `handle` already points to `C_NULL`, this is a no-op.

NOTE: handles obrained through the argumentless `ConfigHandle` constructor DO NOT NEED to be (but optionally CAN be) freed manually, this is automatically handled by a finalizer.
"""
function free_config_handle!(handle::ConfigHandle)
    handle.ptr == C_NULL && return

    ccall((LIBSTC_FREE_CFG, libstc), Cvoid, (Ptr{Cvoid},), handle.ptr)
    handle.ptr = C_NULL
end

macro _gen_cfg_setters()
    fn_defs::Vector{Expr} = Expr[]
    sizehint!(fn_defs, length(CFG_OPTIONS) - 1)

    for (opt, ValTy) in CFG_OPTIONS
        opt == :err_dump_verbosity && continue

        fn_name = Symbol("set_", opt, "!")
        lib_fn_const = Symbol("LIBSTC_SET_", uppercase(string(opt)))

        doc_str = """
            $fn_name(handle::ConfigHandle, value::$ValTy)
            $fn_name(ptr::Ptr{Cvoid}, value::$ValTy)
        
        Wrapper for modifying the `$opt` transpiler option from Julia.
        """

        ArgTy = ValTy == String ? Cstring : ValTy

        fn_def = quote
            export $fn_name

            @doc $doc_str
            function $fn_name(ptr::Ptr{Cvoid}, value::$ValTy)
                ptr == C_NULL && return
                ccall(($lib_fn_const, libstc), Cvoid, (Ptr{Cvoid}, $ArgTy), ptr, value)
            end

            function $fn_name(handle::ConfigHandle, value::$ValTy)
                $(fn_name)(handle.ptr, value)
            end
        end

        push!(fn_defs, fn_def)
    end

    return esc(Expr(:block, fn_defs...))
end

@_gen_cfg_setters

macro _gen_main_setter()
    fn::Expr = :(
        function set_config_opts!(handle::ConfigHandle;)
            handle.ptr == C_NULL && return
        end
    )

    fn_kwargs::Expr = fn.args[1].args[2]
    fn_body::Expr = fn.args[2]

    @assert Meta.isexpr(fn_kwargs, :parameters, 0)

    sizehint!(fn_kwargs.args, length(CFG_OPTIONS))
    sizehint!(fn_body.args, length(CFG_OPTIONS) + 3) # 2 generated line number nodes + null check

    for (opt, ValTy) in CFG_OPTIONS
        setter_name::Symbol = Symbol("set_", opt, "!")

        kwarg::Expr = Expr(:kw, :($(opt)::Union{$ValTy,Nothing}), nothing)
        push!(fn_kwargs.args, kwarg)

        push!(fn_body.args, :(
            if $opt !== nothing
                $setter_name(handle, $opt)
            end
        ))

    end

    return esc(fn)
end

function _gen_main_setter_docs()
    doc_lines::Vector{String} = String[
        "set_config_opts!(handle::ConfigHandle; kwargs...)",
        "",
        "Sets the provided options for the configuration pointed to by `handle`. Acts as a no-op if `handle` points to `C_NULL`.
        Otherwise identical to calling the ShaderTranspiler.Config.set_<option name>! functions for every argument individually.",
        "",
        "kwarg options are:"
    ]
    sizehint!(doc_lines, length(doc_lines) + length(CFG_OPTIONS))

    for (opt, ValTy) in CFG_OPTIONS
        push!(doc_lines, "- $(replace(string(opt), '_' => "\\_"))::$ValTy")
    end

    doc_str = join(doc_lines, '\n')
end

export set_config_opts!

@doc _gen_main_setter_docs()
@_gen_main_setter

end
