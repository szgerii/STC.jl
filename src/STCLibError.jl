"""
    STCLibError(lib_fn_name::Symbol, msg::String, append_general_msg::Bool = true)

Exception thrown when an unexpected error occurs during interaction with
the base stc transpiler library via `ccall`.

This error is intended to wrap low-level failures originating from the C
library boundary. It is not meant to replace or wrap `ccall`'s thrown errors, only
invalid returns from the library (e.g. C_NULL) and such.

In most cases, these failures indicate either:
- an internal error within the stc library,
- invalid or inconsistent state passed across the FFI boundary, or
- resource exhaustion (e.g. system is out of memory)

# Fields
- `lib_fn_name::Symbol`: Name of the lib function that was called.
- `msg::String`: Human-readable error message describing the failure.
- if `append_general_msg` is `true`, a generic explanation about possible causes is appended to `msg`.
"""
struct STCLibError <: Exception
    lib_fn_name::Symbol
    msg::String

    function STCLibError(lib_fn_name::Symbol, msg::String, append_general_msg::Bool=true)
        if append_general_msg
            if endswith(msg, ' ')
                msg *= ' '
            end

            msg *= "This error typically indicates that the system is out of memory, or some unexpected internal library error occured."
        end

        new(lib_fn_name, msg)
    end

    function STCLibError(lib_fn_name::Symbol)
        new(lib_fn_name, "Unexpected library error when calling function $lib_fn_name of the underlying stc library.", true)
    end
end
