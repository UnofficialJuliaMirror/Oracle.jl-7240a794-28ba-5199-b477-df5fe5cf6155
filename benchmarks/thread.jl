
import Oracle
using Dates

@assert VERSION >= v"0.7-"

@assert isfile(joinpath(@__DIR__, "..", "test","credentials.jl")) """
Before running tests, create a file `test/credentials.jl` with the content:

username = "your-username"
password = "your-password"
connect_string = "your-connect-string"
auth_mode = Oracle.ORA_MODE_AUTH_DEFAULT # or Oracle.ORA_MODE_AUTH_SYSDBA if user is SYSDBA
"""
include(joinpath(@__DIR__, "..", "test","credentials.jl"))

function main()
    conn = Oracle.Connection(username, password, connect_string)

    @sync begin
        @async begin
            println("will ping the server")
            Oracle.ping(conn)
            println("pong!!")
        end

        for i in 1:10
            println("$i")
            sleep(0.1)
        end
    end

    println("sync block end")

    Oracle.close!(conn)
end

main()
