using Test
using ShaderTranspiler
using JuliaGLM

@testset "ShaderTranspiler.jl" begin

    # we mostly check for the lib not throwing any errors here
    @testset "Config API" begin
        cfg = ConfigHandle()
        @test cfg.ptr != C_NULL

        # tests underlying setters as well
        set_config_opts!(cfg;
            use_tabs=true,
            code_gen_indent=UInt16(2),
            forward_fns=false,
            dump_parsed=true,
            dump_lowered=true,
            warn_on_jl_sema_query=true
        )

        set_err_dump! = ShaderTranspiler.Config.set_err_dump_verbosity!

        set_err_dump!(cfg, ShaderTranspiler.ERR_DUMP_NONE)
        set_err_dump!(cfg.ptr, ShaderTranspiler.ERR_DUMP_NONE)
        set_err_dump!(cfg, ShaderTranspiler.ERR_DUMP_PARTIAL)
        set_err_dump!(cfg.ptr, ShaderTranspiler.ERR_DUMP_PARTIAL)
        set_err_dump!(cfg, ShaderTranspiler.ERR_DUMP_VERBOSE)
        set_err_dump!(cfg.ptr, ShaderTranspiler.ERR_DUMP_VERBOSE)

        @test_throws DomainError set_err_dump!(cfg, 0x03)
        @test_throws DomainError set_err_dump!(cfg, 0xff)

        free_config_handle!(cfg)
        @test cfg.ptr == C_NULL
    end

    # this doesn't aim to test transpilation results, only their success
    @testset "Transpilation API" begin
        function capture_stderr(f)
            pipe = Pipe()

            result = redirect_stderr(f, pipe)
            close(pipe.in)

            stderr_output = read(pipe.out, String)
            close(pipe.out)

            return (result, stderr_output)
        end

        successful_transpile(result) =
            result isa String && !isempty(result)

        failed_transpile(result) = result isa String && isempty(result)

        valid_ast = quote
            function main()
                x = vec3(0) .+ vec3(1)
            end
        end

        res = transpile(valid_ast)
        @test successful_transpile(res)

        invalid_ast = quote
            function main()
                x = 1
                x = vec3(0)
            end
        end

        (res, stderr_out) = capture_stderr(() -> transpile(invalid_ast))
        @test failed_transpile(res)
        @test !isempty(stderr_out)

        # test if config works
        cfg = ConfigHandle()
        set_config_opts!(cfg; use_tabs=true)

        res = transpile(valid_ast; cfg)
        @test successful_transpile(res)

        # fn forwarding allows non-target builtin functions to be transpiled
        # if they can be found on the Julia side, so e.g. println here works
        # with fn forwarding ONLY
        fn_fwd_ast = quote
            function main()
                println(2)
            end
        end

        free_config_handle!(cfg)
        cfg = ConfigHandle()

        set_config_opts!(cfg; forward_fns=true, warn_on_fn_forward=true)

        (res, stderr_out) = capture_stderr(() -> transpile(fn_fwd_ast; cfg))
        @test successful_transpile(res)
        @test !isempty(stderr_out)

        set_config_opts!(cfg; forward_fns=false)
        (res, stderr_out) = capture_stderr(() -> transpile(fn_fwd_ast; cfg))
        @test failed_transpile(res)
        @test !isempty(stderr_out)

        free_config_handle!(cfg)
        cfg = ConfigHandle()

        # uses 1234 to guarantee this is not the default setting
        set_config_opts!(cfg; target_version="1234 core")

        res = transpile(valid_ast; cfg)
        @test successful_transpile(res)
        @test startswith(res, "#version 1234 core")

        # creates a temporary file to read
        mktemp() do path, io
            write(io, "function main() x = 2 end")
            close(io)

            res = transpile_file(path)
            @test successful_transpile(res)
        end
    end

    # these are no-ops on the Julia side, so we just check that they correctly unwrap
    @testset "Qualifier Macros" begin
        non_lq_quals = [
            :const, :in, :out, :inout, :attribute, :uniform, :varying, :buffer,
            :shared, :centroid, :sample, :patch, :smooth, :flat, :noperspective,
            :lowp, :mediump, :highp, :invariant, :precise, :subroutine, :coherent,
            :volatile, :restrict, :readonly, :writeonly
        ]

        # we have to create temporary globals, which is not great but it's only for testing
        for qual in non_lq_quals
            qual_macro = Symbol("@gl_", qual)
            tmp_sym = gensym(string(qual, "_test"))

            assign_expr = Expr(:macrocall, qual_macro, LineNumberNode(0), :($(tmp_sym)::Int = 10))
            eval(assign_expr)

            @test eval(:($tmp_sym == 10))
        end

        # Test the layout macro
        @test_nowarn @eval @gl_layout(location = 0, global out_color::Float32 = 1.0)
    end

end
