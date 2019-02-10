
# Oracle.jl

This package provides a driver to access Oracle databases using the Julia language,
based on [ODPI-C](https://github.com/oracle/odpi) bindings.

## Requirements

* [Julia](https://julialang.org/) v0.6, v0.7 or v1.0.

* Oracle's [Instant Client](https://www.oracle.com/technetwork/database/database-technologies/instant-client/overview/index.html).

* Linux or macOS.

* C compiler.

## Instant Client installation

This package requires Oracle's [Instant Client](https://www.oracle.com/technetwork/database/database-technologies/instant-client/overview/index.html).

To install it, follow these instructions:

* [Download](https://www.oracle.com/technetwork/database/database-technologies/instant-client/downloads/index.html) instant client.

* Unzip and add `instantclient` folder to your LD_LIBRARY_PATH:

```
export LD_LIBRARY_PATH=/path-to-folder/instantclient_XX_Y:$LD_LIBRARY_PATH
```

Check [ODPI-C documentation](https://oracle.github.io/odpi/doc/installation.html),
or [Instant Client documentation](https://www.oracle.com/technetwork/database/database-technologies/instant-client/documentation/index.html)
for alternative installation methods.

## Package installation

```julia
julia> Pkg.add("Oracle")
```

## Tutorial

### Getting a Connection

```julia
import Oracle

username = "my_username"
password = "my_password"
connect_string = "//IP_ADDRESS/XE" # a valid Oracle connect string

conn = Oracle.Connection(username, password, connect_string)
```

Currently, this driver only supports connections using ASCII or UTF-8 encodings.
All connections are created using UTF-8 encoding by default, for both CHAR and NCHAR.

To connect as SYSDBA, use the appropriate `auth_mode` parameter.

```julia
conn = Oracle.Connection(username, password, connect_string, auth_mode=Oracle.ORA_MODE_AUTH_SYSDBA)
```

Connections are closed automatically (by the garbage collector) when they go out of scope. But you can also close a connection using `Oracle.close!` method.

```julia
Oracle.close!(conn)
```

### Executing a Statement

```julia
Oracle.execute!(conn, "CREATE TABLE TB_TEST ( ID INT NULL )")
Oracle.execute!(conn, "INSERT INTO TB_TEST ( ID ) VALUES ( 1 )")
Oracle.execute!(conn, "INSERT INTO TB_TEST ( ID ) VALUES ( null )")
Oracle.commit!(conn) # will commit 2 lines

Oracle.execute!(conn, "INSERT INTO TB_TEST ( ID ) VALUES ( 3 )")
Oracle.rollback!(conn) # abort insertion of the third line
```

### Binding values to a Statement

```julia
Oracle.execute!(conn, "CREATE TABLE TB_BIND ( ID NUMBER(15,0) NULL, FLT NUMBER(15,4) NULL, STR VARCHAR(255) NULL, DT DATE NULL)")

stmt = Oracle.Stmt(conn, "INSERT INTO TB_BIND ( ID, FLT, STR, DT ) VALUES ( :id, :flt, :str, :dt )")

# will add a single line to TB_BIND
stmt[:id] = 1
stmt[:flt] = 10.23
stmt[:str] = "a string"
stmt[:dt] = Date(2018,12,31)
Oracle.execute!(stmt)

Oracle.commit!(conn)
Oracle.close!(stmt)
```

Statements are closed automatically (by the garbage collector) when they go out of scope.
But it's good practice to close a Statement using `Oracle.close!` method as soon as you have
finished with it, to release database resources.

### Executing a Query

Use `Oracle.query` method with *do-syntax* to get a reference to a cursor.

```julia
Oracle.query(conn, "SELECT * FROM TB_BIND") do cursor
    for row in cursor
        println( row["ID"]  )
        println( row["FLT"] )
        println( row["STR"] )
        println( row["DT"]  )
    end
end
```

You can also use a prepared statement to execute a query.

```julia
stmt = Oracle.Stmt(conn, "SELECT FLT FROM TB_BIND WHERE ID = :id")
stmt[:id] = 1

Oracle.query(stmt) do cursor
    for row in cursor
      println(row["FLT"])
    end
end

Oracle.close!(stmt)
```

### Batch statement execution

If you need to execute the same statement many times but binding different values each time,
pass a vector of columns to `Oracle.execute!` method.

This will use the ODPI-C *executeMany* feature.

```julia
NUM_ROWS = 1_000

column_1 = [ i for i in 1:NUM_ROWS ]
column_2 = .5 * column_1

sql = "INSERT INTO TB_BENCH_EXECUTE_MANY ( ID, FLT ) VALUES ( :1, :2 )"
Oracle.execute!(conn, sql, [ column_1, column_2 ])
```

### Session Pools

A *Pool* represents a pool of connections, and provides a faster way to acquire connections to the database.

```julia
# creates a pool for a maximum of 2 sessions
pool = Oracle.Pool(username, password, connect_string, max_sessions=2, session_increment=1)

conn_1 = Oracle.Connection(pool)
conn_2 = Oracle.Connection(pool) # at this point, we can't acquire more connections

# release a connection so that we can acquire another one.
Oracle.close!(conn_1)

# by now, acquiring a new connection should be pretty fast
# since the new connection will be taken from the pool
conn_3 = Oracle.Connection(pool)

# release all connections that are still open
Oracle.close!(conn_2)
Oracle.close!(conn_3)

Oracle.close!(pool)
```

A *Pool* is closed automatically (by the garbage collector) when it goes out of scope.
You can use `Oracle.close!` method as soon as you have
finished with it, to release database resources.

### LOB

Oracle LOB fields can hold [up to 4GB of data](https://docs.oracle.com/cd/B28359_01/server.111/b28320/limits001.htm).

They come in two flavors:

* Binary LOBs: BLOB or BFILE.

* Character LOBs: CLOB or NCLOB.

LOB values are represented as a value of type `Oracle.Lob` in this package.

From a LOB value, you can use `read` and `write` methods to manipulate whole contents of the LOB value.
For incremental reading/writing, you can use `open` with *do-syntax* do get an IO stream out of a `Oracle.Lob`.

IO Streams created on Character LOBs use the character index as its position, and
only support reading/writing for `Char` and `String` data types.

A LOB is closed automatically (by the garbage collector) when it goes out of scope.
You can use `Oracle.close!` method as soon as you have
finished with it, to release database resources.

*Currently, BFILE is not supported.*

#### Reading from a BLOB

```julia
lyric = "hey you. 🎵 🎶 Out there in the cold. getting lonely, getting old. Can you feel me? 📼📼📼📼"

Oracle.execute!(conn, "CREATE TABLE TB_BLOB ( b BLOB )")
Oracle.execute!(conn, "INSERT INTO TB_BLOB ( B ) VALUES ( utl_raw.cast_to_raw('$lyric'))")

Oracle.query(conn, "SELECT B FROM TB_BLOB") do cursor
    for row in cursor
        blob = row["B"]
        bytes_vector = read(blob) # Vector{UInt8}
        println(String(bytes_vector))
    end
end
```

#### Writing to a BLOB

Follow these steps to write to a BLOB field in the database.

1. Create a temporary Lob associated with the connection using `Oracle.Lob(connection, oracle_type)`.

2. Write data to the Lob.

3. Wrap the Lob into a Variable.

4. Bind the variable to the statement.

5. Execute the statement.

```julia
Oracle.execute!(conn, "CREATE TABLE TB_BLOB_VARIABLE ( B BLOB )")

test_data = rand(UInt8, 5000)

# creates a temporary Lob bounded to the Connection
blob = Oracle.Lob(conn, Oracle.ORA_ORACLE_TYPE_BLOB)

# replaces all Lob data with the contents of the array test_data
write(blob, test_data)

# wraps the blob in a Variable
ora_var = Oracle.Variable(conn, blob)

stmt = Oracle.Stmt(conn, "INSERT INTO TB_BLOB_VARIABLE ( B ) VALUES ( :1 )")

# binds the variable to the statement
stmt[1] = ora_var

Oracle.execute!(stmt)
Oracle.close!(stmt)
```

## ODPI-C Naming Conventions

All enums, constants and structs in ODPI-C library use the prefix `DPI` or `dpi`.

In *Oracle.jl*, the Julia implementation of these elements use the prefix `ORA` or `Ora`.

Examples:

* The ODPI-C constant `DPI_MODE_AUTH_SYSDBA` becomes `ORA_MODE_AUTH_SYSDBA` in Julia.

* The ODPI-C enum `dpiAuthMode` becomes `OraAuthMode` in Julia.

* The ODPI-C struct `dpiTimestamp` becomes `OraTimestamp` in Julia.

All julia structs with prefix `Ora` are raw wrappers around ODPC-C structs and may contain unsafe attributes.

Safe equivalent Julia structs drop the `Ora` prefix.

ODPI-C *function wrappers* have their name preserved, as in `dpiContext_create`.

## License

The source code for the package *Oracle.jl* is licensed under the [MIT License](https://github.com/felipenoris/Oracle.jl/blob/master/LICENSE).

During installation, *Oracle.jl* downloads the source code and compile the library [ODPI-C](https://github.com/oracle/odpi)
which is licensed under [The Universal Permissive License (UPL), Version 1.0](https://oracle.github.io/odpi/doc/license.html) and/or the [Apache License](https://oracle.github.io/odpi/doc/license.html).
