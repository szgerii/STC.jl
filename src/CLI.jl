module CLI

using stc_jll

function (@main)(ARGS)
    stc_jll.stc_cli() do exe
        cmd = `$exe $ARGS`
        proc = run(ignorestatus(cmd))
        
        return proc.exitcode
    end
end

end
