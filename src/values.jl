
const SIZEOF_ORA_DATA = sizeof(Oracle.OraData)

is_null(val::NativeValue, offset::Integer=0) = is_null(val.data_handle + offset*SIZEOF_ORA_DATA)
is_null(ptr::Ptr{OraData}) = Bool(dpiData_getIsNull(ptr))

#=
"""
    julia_type(native_type::OraNativeTypeNum) :: DataType

Returns the equivalente julia type for an Oracle native type.
"""
function julia_type(nt::OraNativeTypeNum) :: DataType
    nt == ORA_NATIVE_TYPE_DOUBLE    && return Float64
    nt == ORA_NATIVE_TYPE_BOOLEAN   && return Bool
    nt == ORA_NATIVE_TYPE_FLOAT     && return Float32
    nt == ORA_NATIVE_TYPE_INT64     && return Int64
    nt == ORA_NATIVE_TYPE_UINT64    && return UInt64
    nt == ORA_NATIVE_TYPE_BYTES     && return String
    nt == ORA_NATIVE_TYPE_TIMESTAMP && return OraTimestamp

    error("Native type $native_type not supported by method `Oracle.julia_type`.")
end
=#

OraNativeTypeNum(::Type{Float64})      = ORA_NATIVE_TYPE_DOUBLE
OraNativeTypeNum(::Type{Bool})         = ORA_NATIVE_TYPE_BOOLEAN
OraNativeTypeNum(::Type{Float32})      = ORA_NATIVE_TYPE_FLOAT
OraNativeTypeNum(::Type{Int64})        = ORA_NATIVE_TYPE_INT64
OraNativeTypeNum(::Type{UInt64})       = ORA_NATIVE_TYPE_UINT64
OraNativeTypeNum(::Type{String})       = ORA_NATIVE_TYPE_BYTES
OraNativeTypeNum(::Type{OraTimestamp}) = ORA_NATIVE_TYPE_TIMESTAMP
OraNativeTypeNum(::Type{Date})         = ORA_NATIVE_TYPE_TIMESTAMP
OraNativeTypeNum(::Type{DateTime})     = ORA_NATIVE_TYPE_TIMESTAMP

get_data_handle(val::NativeValue, offset::Integer=0) = val.data_handle + offset*SIZEOF_ORA_DATA

function parse_native_value(val::NativeValue, offset::Integer=0)

    data_handle = get_data_handle(val, offset)

    if is_null(data_handle)
        return missing

    elseif val.native_type == ORA_NATIVE_TYPE_DOUBLE
        return dpiData_getDouble(data_handle)

    elseif val.native_type == ORA_NATIVE_TYPE_BOOLEAN
        return Bool(dpiData_getBool(data_handle))

    elseif val.native_type == ORA_NATIVE_TYPE_FLOAT
        return dpiData_getFloat(data_handle)

    elseif val.native_type == ORA_NATIVE_TYPE_INT64
        return dpiData_getInt64(data_handle)

    elseif val.native_type == ORA_NATIVE_TYPE_UINT64
        return dpiData_getUint64(data_handle)

    elseif val.native_type == ORA_NATIVE_TYPE_BYTES
        ptr_bytes = dpiData_getBytes(data_handle) # get a Ptr{OraBytes}
        ora_string = unsafe_load(ptr_bytes) # get a OraBytes
        enc = unsafe_string(ora_string.encoding)
        if enc == "ASCII" || enc == "UTF-8"
            return unsafe_string(ora_string.ptr, ora_string.length)
        else
            error("String encoding not supported: $enc.")
        end

    elseif val.native_type == ORA_NATIVE_TYPE_TIMESTAMP
        ptr_native_timestamp = dpiData_getTimestamp(data_handle)
        return unsafe_load(ptr_native_timestamp)
    else
        error("Data Type not supported: $(Int(val.native_type))")
    end
end

Base.getindex(val::NativeValue) = parse_native_value(val)
Base.getindex(val::NativeValue, offset::Integer) = parse_native_value(val, offset)
Base.setindex!(native_value::NativeValue, value, offset::Integer) = set_native_value!(native_value, value, offset)

@generated function set_native_value!(native_value::NativeValue, val::T, offset::Integer) where {T}

    if val <: Missing
        return quote
            dpiData_setNull_ptr(get_data_handle(native_value, offset))
        end
    end

    if val <: Float64
        native_type = :ORA_NATIVE_TYPE_DOUBLE
        set_value_function = :dpiData_setDouble_ptr
    elseif val <: Int64
        native_type = :ORA_NATIVE_TYPE_INT64
        set_value_function = :dpiData_setInt64_ptr
    else
        error("Native type $val not supported.")
    end

    return quote
        @assert native_value.native_type == $native_type
        $(set_value_function)(get_data_handle(native_value, offset), val)
        nothing
    end
end

encoding(ora_string::OraBytes) = unsafe_string(ora_string.encoding)

function encoding(ora_string_ptr::Ptr{OraBytes})
    ora_string = unsafe_load(ora_string_ptr)
    return encoding(ora_string)
end

function encoding(val::NativeValue)
    @assert val.native_type == ORA_NATIVE_TYPE_BYTES "Native type must be Oracle.ORA_NATIVE_TYPE_BYTES. Found: $(val.native_type)."
    ptr_bytes = dpiData_getBytes(val.data_handle)
    return encoding(ptr_bytes)
end


function parse_value(column_info::OraQueryInfo, ::Missing) :: Missing
    # if we got a null value, it must be ok for the schema to have a null value in this columns
    @assert column_info.null_ok == 1
    return missing
end

function parse_value(column_info::OraQueryInfo, num::Float64)
    if column_info.type_info.oracle_type_num == ORA_ORACLE_TYPE_NUMBER && column_info.type_info.scale <= 0
        return Int(num)
    else
        return num
    end
end

function parse_value(column_info::OraQueryInfo, ts::OraTimestamp)
    ora_type = column_info.type_info.oracle_type_num

    if ora_type == ORA_ORACLE_TYPE_DATE
        @assert ts.fsecond == 0
        @assert ts.tzHourOffset == 0
        @assert ts.tzMinuteOffset == 0
        return DateTime(ts.year, ts.month, ts.day, ts.hour, ts.minute, ts.second)

    elseif ora_type == ORA_ORACLE_TYPE_TIMESTAMP
        @assert ts.tzHourOffset == 0
        @assert ts.tzMinuteOffset == 0
        return DateTime(ts.year, ts.month, ts.day, ts.hour, ts.minute, ts.second, ts.fsecond * (1e-6) )
    else
        error("oracle_type_num $(column_info.type_info.oracle_type_num) not supported.")
    end
end

function parse_value(column_info::OraQueryInfo, val::T) :: T where {T}
    # catches all other cases
    val
end
