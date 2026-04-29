module LibSyms

# used for init-time lib validation
const _LIB_FN_SYMS = Symbol[]

const _lib_fn_prefix::Symbol = :stc_

function _decl_fn(fn_name::Symbol, prepend_prefix::Bool=true)
    lib_fn::Symbol = prepend_prefix ? Symbol(_lib_fn_prefix, fn_name) : fn_name

    push!(_LIB_FN_SYMS, lib_fn)

    return lib_fn
end

export LIBSTC_ABI_VERSION
const LIBSTC_ABI_VERSION::Symbol = _decl_fn(:abi_version)

# Transpile API
export LIBSTC_TRANSPILE, LIBSTC_GET_RESULT, LIBSTC_FREE_RESULT

const LIBSTC_TRANSPILE::Symbol = _decl_fn(:transpile)
const LIBSTC_GET_RESULT::Symbol = _decl_fn(:get_result)
const LIBSTC_FREE_RESULT::Symbol = _decl_fn(:free_result)

# Config API
export LIBSTC_CREATE_CFG, LIBSTC_FREE_CFG, CFG_OPTIONS

const LIBSTC_CREATE_CFG::Symbol = _decl_fn(:create_cfg)
const LIBSTC_FREE_CFG::Symbol = _decl_fn(:free_cfg)

const CFG_OPTIONS = [
    (:code_gen_indent, UInt16),
    (:dump_indent, UInt16),
    (:err_dump_verbosity, UInt8),
    (:use_tabs, Bool),
    (:forward_fns, Bool),
    (:warn_on_fn_forward, Bool),
    (:warn_on_jl_sema_query, Bool),
    (:print_convert_fail_reason, Bool),
    (:track_bindings, Bool),
    (:coerce_to_f32, Bool),
    (:coerce_to_i32, Bool),
    (:capture_uniforms, Bool),
    (:dump_scopes, Bool),
    (:dump_parsed, Bool),
    (:dump_sema, Bool),
    (:dump_lowered, Bool),
    (:target_version, String),
    (:local_size, Tuple{UInt32,UInt32,UInt32})
]

macro _gen_cfg_consts()
    exprs::Vector{Expr} = Expr[]
    sizehint!(exprs, length(CFG_OPTIONS) * 2)

    for (opt, _) in CFG_OPTIONS
        lib_fn::Symbol = Symbol("set_", opt)
        const_name::Symbol = Symbol("LIBSTC_", uppercase(string(lib_fn)))

        push!(exprs, :(export $const_name))
        push!(exprs, :(const $const_name::Symbol = $(_decl_fn)($(QuoteNode(lib_fn)))))
    end

    return esc(Expr(:block, exprs...))
end

@_gen_cfg_consts

end
