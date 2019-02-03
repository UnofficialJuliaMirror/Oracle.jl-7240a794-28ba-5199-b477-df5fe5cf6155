
# https://oracle.github.io/odpi/doc/user_guide/data_types.html

const SIZEOF_ORA_DATA = sizeof(Oracle.OraData)

@inline function oracle_type(v::AbstractOracleValue{O,N}) :: OraOracleTypeNum where {O,N}
    return O
end

@inline function native_type(v::AbstractOracleValue{O,N}) :: OraNativeTypeNum where {O,N}
    return N
end

@inline parent(v::ExternOracleValue) = v.parent
@inline parent(v::JuliaOracleValue) = error("Not implemented.")

@inline function get_data_handle(val::ExternOracleValue, offset::Integer) :: Ptr{OraData}
    return val.data_handle + offset*SIZEOF_ORA_DATA
end

@inline function get_data_handle(val::ExternOracleValue) :: Ptr{OraData}
    # equivalent of get_data_handle(val, 0)
    return val.data_handle
end

@inline function get_data_handle(val::JuliaOracleValue, offset::Integer) :: Ptr{OraData}
    return pointer(val.buffer, offset+1)
end

@inline function get_data_handle(val::JuliaOracleValue) :: Ptr{OraData}
    # equivalent of get_data_handle(val, 0)
    return pointer(val.buffer)
end

@inline parse_oracle_value(val::AbstractOracleValue, offset::Integer) = parse_oracle_value_at(val, get_data_handle(val, offset))
@inline parse_oracle_value(val::AbstractOracleValue) = parse_oracle_value_at(val, get_data_handle(val))

@inline is_null(ptr::Ptr{OraData}) = Bool(dpiData_getIsNull(ptr))

@inline function parse_oracle_value_at(val::AbstractOracleValue, data_handle::Ptr{OraData})
    if is_null(data_handle)
        return missing
    else
        parse_non_null_oracle_value_at(val, data_handle)
    end
end

# O -> OraOracleTypeNum, N -> OraNativeTypeNum
@generated function parse_non_null_oracle_value_at(val::AbstractOracleValue{O, N}, data_handle::Ptr{OraData}) where {O, N}

    @assert isa(O, OraOracleTypeNum)
    @assert isa(N, OraNativeTypeNum)

    if O == ORA_ORACLE_TYPE_NATIVE_DOUBLE
        @assert N == ORA_NATIVE_TYPE_DOUBLE

        return quote
            dpiData_getDouble(data_handle)
        end
    end

    if O == ORA_ORACLE_TYPE_BOOLEAN
        @assert N == ORA_NATIVE_TYPE_BOOLEAN

        return quote
            Bool(dpiData_getBool(data_handle))
        end
    end

    if O == ORA_ORACLE_TYPE_NATIVE_FLOAT
        @assert N == ORA_NATIVE_TYPE_FLOAT

        return quote
            dpiData_getFloat(data_handle)
        end
    end

    if O == ORA_ORACLE_TYPE_NUMBER

        # DPI_NATIVE_TYPE_DOUBLE, DPI_NATIVE_TYPE_BYTES, DPI_NATIVE_TYPE_INT64, DPI_NATIVE_TYPE_UINT64

        if N == ORA_NATIVE_TYPE_DOUBLE
            return quote
                dpiData_getDouble(data_handle)
            end

        elseif N == ORA_NATIVE_TYPE_BYTES
            error("Numeric values with native type BYTES not supported.")

        elseif N == ORA_NATIVE_TYPE_INT64
            return quote
                dpiData_getInt64(data_handle)
            end

        elseif N == ORA_NATIVE_TYPE_UINT64
            return quote
                dpiData_getUint64(data_handle)
            end

        else
            error("Native type $N not expected for value with numeric oracle type.")
        end
    end

    if N == ORA_NATIVE_TYPE_BYTES
        return quote
            ptr_bytes = dpiData_getBytes(data_handle) # get a Ptr{OraBytes}
            ora_string = unsafe_load(ptr_bytes) # get a OraBytes
            return unsafe_string(ora_string.ptr, ora_string.length)
        end
    end

    if N == ORA_NATIVE_TYPE_TIMESTAMP
        if O == ORA_ORACLE_TYPE_DATE
            return quote
                ptr_native_timestamp = dpiData_getTimestamp(data_handle)
                local ts::OraTimestamp = unsafe_load(ptr_native_timestamp)
                @assert ts.fsecond == 0
                @assert ts.tzHourOffset == 0
                @assert ts.tzMinuteOffset == 0
                return DateTime(ts.year, ts.month, ts.day, ts.hour, ts.minute, ts.second)
            end

        elseif O == ORA_ORACLE_TYPE_TIMESTAMP
            return quote
                ptr_native_timestamp = dpiData_getTimestamp(data_handle)
                local ts::OraTimestamp = unsafe_load(ptr_native_timestamp)
                @assert ts.tzHourOffset == 0
                @assert ts.tzMinuteOffset == 0
                return DateTime(ts.year, ts.month, ts.day, ts.hour, ts.minute, ts.second, ts.fsecond * (1e-6) )
            end
        end
    end

    if N == ORA_NATIVE_TYPE_LOB
        return quote
            ptr_native_lob = dpiData_getLOB(data_handle)
            return Lob(parent(val), ptr_native_lob, O)
        end
    end

    if O == ORA_ORACLE_TYPE_NATIVE_INT
        @assert N == ORA_NATIVE_TYPE_INT64

        return quote
                dpiData_getInt64(data_handle)
        end

    end

    error("Couldn't parse value for oracle type $O, native type $N.")
end

@inline Base.getindex(val::AbstractOracleValue) = parse_oracle_value(val)
@inline Base.getindex(val::AbstractOracleValue, offset::Integer) = parse_oracle_value(val, offset)
@inline Base.setindex!(oracle_value::AbstractOracleValue, value, offset::Integer=0) = set_oracle_value!(oracle_value, value, offset)

@inline function set_oracle_value!(oracle_value::JuliaOracleValue{O,N,T}, val::T, offset::Integer=0) where {O,N,T}
    oracle_value.buffer[offset+1] = val
    nothing
end

@generated function set_oracle_value_at!(oracle_value::AbstractOracleValue{O,N}, val::T, at::Ref{OraData}) where {O,N,T}

    if val <: Missing
        return quote
            dpiData_setNull(at)
        end
    end

    if N == ORA_NATIVE_TYPE_BYTES
        @assert val <: String "Setting byte values to an AbstractOracleValue supports only String values. Got $val."

        return quote
            dpiData_setBytes(at, val)
        end
    end

    if N == ORA_NATIVE_TYPE_BOOLEAN
        return quote
            dpiData_setBool(at, val)
        end
    end

    if N == ORA_NATIVE_TYPE_DOUBLE
        return quote
            dpiData_setDouble(at, val)
        end
    end

    if N == ORA_NATIVE_TYPE_INT64
        return quote
            dpiData_setInt64(at, val)
        end
    end

    if N == ORA_NATIVE_TYPE_TIMESTAMP

        # DPI_ORACLE_TYPE_DATE, DPI_ORACLE_TYPE_TIMESTAMP, DPI_ORACLE_TYPE_TIMESTAMP_LTZ, DPI_ORACLE_TYPE_TIMESTAMP_TZ

        if O == ORA_ORACLE_TYPE_DATE
            @assert val <: Date
        elseif O == ORA_ORACLE_TYPE_TIMESTAMP
            @assert (val <: Date) || (val <: DateTime)
        else
            error("Oracle type $O not supported.")
        end

        return quote
            ts = OraTimestamp(val)
            dpiData_setTimestamp(at, ts)
        end
    end

    error("Setting values to AbstractOracleValue{$O, $N} is not supported.")
end

encoding(ora_string::OraBytes) = unsafe_string(ora_string.encoding)

function encoding(ora_string_ptr::Ptr{OraBytes})
    ora_string = unsafe_load(ora_string_ptr)
    return encoding(ora_string)
end

@generated function encoding(val::AbstractOracleValue{O,N}, offset::Integer=0) where {O,N}
    @assert N == ORA_NATIVE_TYPE_BYTES "Native type must be Oracle.ORA_NATIVE_TYPE_BYTES. Found: $N."

    return quote
        ptr_bytes = dpiData_getBytes(get_data_handle(val, offset))
        return encoding(ptr_bytes)
    end
end

#
# Get/Set Implementation for JuliaOracleValue
#

@inline function parse_oracle_value(oracle_value::JuliaOracleValue{O,N,T}, offset::Integer=0) where {O,N,T}
    return oracle_value.buffer[offset+1]
end

@inline function set_oracle_value!(oracle_value::AbstractOracleValue{O,N}, val::T, offset::Integer) where {O,N,T}
    return set_oracle_value_at!(oracle_value, val, get_data_handle(oracle_value, offset))
end

struct OracleTypeTuple
    oracle_type::OraOracleTypeNum
    native_type::OraNativeTypeNum
end

# accept julia types as arguments
@inline infer_oracle_type_tuple(::Type{Bool}) = OracleTypeTuple(ORA_ORACLE_TYPE_BOOLEAN, ORA_NATIVE_TYPE_BOOLEAN)
@inline infer_oracle_type_tuple(::Type{Float64}) = OracleTypeTuple(ORA_ORACLE_TYPE_NATIVE_DOUBLE, ORA_NATIVE_TYPE_DOUBLE)
@inline infer_oracle_type_tuple(::Type{Int64}) = OracleTypeTuple(ORA_ORACLE_TYPE_NATIVE_INT, ORA_NATIVE_TYPE_INT64)
@inline infer_oracle_type_tuple(::Type{UInt64}) = OracleTypeTuple(ORA_ORACLE_TYPE_NATIVE_UINT, ORA_NATIVE_TYPE_UINT64)
@inline infer_oracle_type_tuple(::Type{Date}) = OracleTypeTuple(ORA_ORACLE_TYPE_DATE, ORA_NATIVE_TYPE_TIMESTAMP)
@inline infer_oracle_type_tuple(::Type{DateTime}) = OracleTypeTuple(ORA_ORACLE_TYPE_TIMESTAMP, ORA_NATIVE_TYPE_TIMESTAMP)

# accept julia values as arguments
for type_sym in (:Bool, :Float64, :Int64, :UInt64, :Date, :DateTime)
    @eval begin
        @inline infer_oracle_type_tuple(::$type_sym) = infer_oracle_type_tuple($type_sym)
    end
end

@inline function infer_oracle_type_tuple(s::String)
    # max VARCHAR2 size is 4000 bytes
    if sizeof(s) <= 4000
        return OracleTypeTuple(ORA_ORACLE_TYPE_NVARCHAR, ORA_NATIVE_TYPE_BYTES)
    else
        return OracleTypeTuple(ORA_ORACLE_TYPE_NCLOB, ORA_NATIVE_TYPE_LOB)
    end
end

@inline function infer_oracle_type_tuple(::Type{String})
    # without information about string length, will best guess as a NVARCHAR
    return OracleTypeTuple(ORA_ORACLE_TYPE_NVARCHAR, ORA_NATIVE_TYPE_BYTES)
end

@generated function JuliaOracleValue(scalar::T) where {T}
    # TODO
    @assert !(scalar <: Vector) "Vector not supported."

    return quote
        ott = infer_oracle_type_tuple(scalar)
        val = JuliaOracleValue(ott.oracle_type, ott.native_type, T)
        val[] = scalar
        return val
    end
end