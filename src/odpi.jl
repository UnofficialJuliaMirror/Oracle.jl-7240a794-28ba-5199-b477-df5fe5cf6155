
# int dpiContext_create(unsigned int majorVersion, unsigned int minorVersion, dpiContext **context, dpiErrorInfo *errorInfo)
function dpiContext_create(major_version::UInt32, minor_version::UInt32, dpi_context_ref::Ref{Ptr{Cvoid}}, dpi_error_info::Ref{dpiErrorInfo})
    ccall((:dpiContext_create, libdpi), dpiResult, (Cuint, Cuint, Ref{Ptr{Cvoid}}, Ref{dpiErrorInfo}), major_version, minor_version, dpi_context_ref, dpi_error_info)
end

# int dpiContext_destroy(dpiContext *context)
function dpiContext_destroy(dpi_context_handle::Ptr{Cvoid})
    ccall((:dpiContext_destroy, libdpi), dpiResult, (Ptr{Cvoid},), dpi_context_handle)
end

# void dpiContext_getClientVersion(const dpiContext *context, dpiVersionInfo *versionInfo)
function dpiContext_getClientVersion(dpi_context_handle::Ptr{Cvoid}, dpi_version_info_ref::Ref{dpiVersionInfo})
    ccall((:dpiContext_getClientVersion, libdpi), Cvoid, (Ptr{Cvoid}, Ref{dpiVersionInfo}), dpi_context_handle, dpi_version_info_ref)
end

# int dpiContext_initCommonCreateParams(const dpiContext *context, dpiContextParams *params)
function dpiContext_initCommonCreateParams(dpi_context_handle::Ptr{Cvoid}, dpi_common_create_params_ref::Ref{dpiCommonCreateParams})
    ccall((:dpiContext_initCommonCreateParams, libdpi), dpiResult, (Ptr{Cvoid}, Ref{dpiCommonCreateParams}), dpi_context_handle, dpi_common_create_params_ref)
end

# int dpiPool_release(dpiPool *pool)
function dpiPool_release(dpi_pool_handle::Ptr{Cvoid})
    ccall((:dpiPool_release, libdpi), dpiResult, (Ptr{Cvoid},), dpi_pool_handle)
end

# int dpiContext_initPoolCreateParams(const dpiContext *context, dpiPoolCreateParams *params)
function dpiContext_initPoolCreateParams(context_handle::Ptr{Cvoid}, dpi_pool_create_params_ref::Ref{dpiPoolCreateParams})
    ccall((:dpiContext_initPoolCreateParams, libdpi), dpiResult, (Ptr{Cvoid}, Ref{dpiPoolCreateParams}), context_handle, dpi_pool_create_params_ref)
end

# int dpiPool_create(const dpiContext *context, const char *userName, uint32_t userNameLength, const char *password, uint32_t passwordLength, const char *connectString, uint32_t connectStringLength, dpiCommonCreateParams *commonParams, dpiPoolCreateParams *createParams, dpiPool **pool)
function dpiPool_create(context_handle::Ptr{Cvoid}, user::String, password::String, connect_string::String, common_params_ref::Ref{dpiCommonCreateParams}, pool_create_params_ref::Ref{dpiPoolCreateParams}, dpi_pool_handle_ref::Ref{Ptr{Cvoid}})
    (userName, userNameLength) = (user, sizeof(user))
    (password, passwordLength) = (password, sizeof(password))
    (connectString, connectStringLength) = (connect_string, sizeof(connect_string))

    ccall((:dpiPool_create, libdpi), dpiResult, (Ptr{Cvoid}, Ptr{UInt8}, UInt32, Ptr{UInt8}, UInt32, Ptr{UInt8}, UInt32, Ref{dpiCommonCreateParams}, Ref{dpiPoolCreateParams}, Ref{Ptr{Cvoid}}), context_handle, userName, userNameLength, password, passwordLength, connectString, connectStringLength, common_params_ref, pool_create_params_ref, dpi_pool_handle_ref)
end

# void dpiContext_getError(const dpiContext *context, dpiErrorInfo *errorInfo)¶
function dpiContext_getError(context_handle::Ptr{Cvoid}, error_info_ref::Ref{dpiErrorInfo})
    ccall((:dpiContext_getError, libdpi), Cvoid, (Ptr{Cvoid}, Ref{dpiErrorInfo}), context_handle, error_info_ref)
end

# int dpiContext_initConnCreateParams(const dpiContext *context, dpiConnCreateParams *params)
function dpiContext_initConnCreateParams(context_handle::Ptr{Cvoid}, conn_create_params_ref::Ref{dpiConnCreateParams})
    ccall((:dpiContext_initConnCreateParams, libdpi), dpiResult, (Ptr{Cvoid}, Ref{dpiConnCreateParams}), context_handle, conn_create_params_ref)
end

# int dpiConn_release(dpiConn *conn)
function dpiConn_release(connection_handle::Ptr{Cvoid})
    ccall((:dpiConn_release, libdpi), dpiResult, (Ptr{Cvoid},), connection_handle)
end

# int dpiConn_create(const dpiContext *context, const char *userName, uint32_t userNameLength, const char *password, uint32_t passwordLength, const char *connectString, uint32_t connectStringLength, dpiCommonCreateParams *commonParams, dpiConnCreateParams *createParams, dpiConn **conn)
function dpiConn_create(context_handle::Ptr{Cvoid}, user::String, password::String, connect_string::String, common_params_ref::Ref{dpiCommonCreateParams}, conn_create_params_ref::Ref{dpiConnCreateParams}, dpi_conn_handle_ref::Ref{Ptr{Cvoid}})
    (userName, userNameLength) = (user, sizeof(user))
    (password, passwordLength) = (password, sizeof(password))
    (connectString, connectStringLength) = (connect_string, sizeof(connect_string))

    ccall((:dpiConn_create, libdpi), dpiResult, (Ptr{Cvoid}, Ptr{UInt8}, UInt32, Ptr{UInt8}, UInt32, Ptr{UInt8}, UInt32, Ref{dpiCommonCreateParams}, Ref{dpiConnCreateParams}, Ref{Ptr{Cvoid}}), context_handle, userName, userNameLength, password, passwordLength, connectString, connectStringLength, common_params_ref, conn_create_params_ref, dpi_conn_handle_ref)
end

# int dpiConn_getServerVersion(dpiConn *conn, const char **releaseString, uint32_t *releaseStringLength, dpiVersionInfo *versionInfo)
function dpiConn_getServerVersion(connection_handle::Ptr{Cvoid}, release_string_ptr_ref::Ref{Ptr{UInt8}}, release_string_length_ref::Ref{UInt32}, version_info_ref::Ref{dpiVersionInfo})
    ccall((:dpiConn_getServerVersion, libdpi), dpiResult, (Ptr{Cvoid}, Ref{Ptr{UInt8}}, Ref{UInt32},Ref{dpiVersionInfo}), connection_handle, release_string_ptr_ref, release_string_length_ref, version_info_ref)
end

#int dpiConn_ping(dpiConn *conn)
function dpiConn_ping(connection_handle::Ptr{Cvoid})
    ccall((:dpiConn_ping, libdpi), dpiResult, (Ptr{Cvoid},), connection_handle)
end

# int dpiConn_startupDatabase(dpiConn *conn, dpiStartupMode mode)
function dpiConn_startupDatabase(connection_handle::Ptr{Cvoid}, startup_mode::dpiStartupMode)
    ccall((:dpiConn_startupDatabase, libdpi), dpiResult, (Ptr{Cvoid}, dpiStartupMode), connection_handle, startup_mode)
end

# int dpiConn_shutdownDatabase(dpiConn *conn, dpiShutdownMode mode)
function dpiConn_shutdownDatabase(connection_handle::Ptr{Cvoid}, shutdown_mode::dpiShutdownMode)
    ccall((:dpiConn_shutdownDatabase, libdpi), dpiResult, (Ptr{Cvoid}, dpiShutdownMode), connection_handle, shutdown_mode)
end

# int dpiStmt_release(dpiStmt *stmt)
function dpiStmt_release(stmt_handle::Ptr{Cvoid})
    ccall((:dpiStmt_release, libdpi), dpiResult, (Ptr{Cvoid},), stmt_handle)
end

# int dpiConn_prepareStmt(dpiConn *conn, int scrollable, const char *sql, uint32_t sqlLength, const char *tag, uint32_t tagLength, dpiStmt **stmt)
function dpiConn_prepareStmt(connection_handle::Ptr{Cvoid}, scrollable::Bool, sql::String, tag::String, stmt_handle_ref::Ref{Ptr{Cvoid}})
    sqlLength = sizeof(sql)

    if tag == ""
        return ccall((:dpiConn_prepareStmt, libdpi), dpiResult, (Ptr{Cvoid}, Cint, Ptr{UInt8}, UInt32, Ptr{UInt8}, UInt32, Ref{Ptr{Cvoid}}), connection_handle, scrollable, sql, sqlLength, C_NULL, 0, stmt_handle_ref)
    else
        tagLength = sizeof(tagLength)
        return ccall((:dpiConn_prepareStmt, libdpi), dpiResult, (Ptr{Cvoid}, Cint, Ptr{UInt8}, UInt32, Ptr{UInt8}, UInt32, Ref{Ptr{Cvoid}}), connection_handle, scrollable, sql, sqlLength, tag, tagLength, stmt_handle_ref)
    end
end

# int dpiStmt_execute(dpiStmt *stmt, dpiExecMode mode, uint32_t *numQueryColumns)
function dpiStmt_execute(stmt_handle::Ptr{Cvoid}, exec_mode::dpiExecMode, num_query_columns_ref::Ref{UInt32})
    ccall((:dpiStmt_execute, libdpi), dpiResult, (Ptr{Cvoid}, dpiExecMode, Ref{UInt32}), stmt_handle, exec_mode, num_query_columns_ref)
end

# int dpiConn_commit(dpiConn *conn)
function dpiConn_commit(connection_handle::Ptr{Cvoid})
    ccall((:dpiConn_commit, libdpi), dpiResult, (Ptr{Cvoid},), connection_handle)
end

# int dpiConn_rollback(dpiConn *conn)
function dpiConn_rollback(connection_handle::Ptr{Cvoid})
    ccall((:dpiConn_rollback, libdpi), dpiResult, (Ptr{Cvoid},), connection_handle)
end