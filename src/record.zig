const std = @import("std");
const events = @import("events");

pub const Error = error{
    InvalidMagic,
    UnsupportedVersion,
    Truncated,
    OutputFull,
    MissingHeader,
    UnknownRecordKind,
    StreamAlreadyDeclared,
    StreamNotDeclared,
    StreamRegistryFull,
    SequenceNotMonotonic,
    NamespaceTooLong,
    PayloadTooLarge,
};

pub const RecordKind = enum(u8) {
    stream_decl = 1,
    event = 2,
};

pub const EventRecord = struct {
    stream_id: u8,
    sequence: u32,
    payload: []const u8,
};

pub const Record = union(enum) {
    stream_decl: events.StreamDecl,
    event: EventRecord,
};

pub fn writeIntLittle(comptime T: type, buf: []u8, offset: *usize, value: T) Error!void {
    const size = @sizeOf(T);
    if (offset.* + size > buf.len) return error.OutputFull;
    const slice = buf[offset.* .. offset.* + size];
    const ptr: *[@sizeOf(T)]u8 = @ptrCast(slice.ptr);
    std.mem.writeInt(T, ptr, value, .little);
    offset.* += size;
}

pub fn readIntLittle(comptime T: type, buf: []const u8, offset: *usize) Error!T {
    const size = @sizeOf(T);
    if (offset.* + size > buf.len) return error.Truncated;
    const slice = buf[offset.* .. offset.* + size];
    const ptr: *const [@sizeOf(T)]u8 = @ptrCast(slice.ptr);
    const value = std.mem.readInt(T, ptr, .little);
    offset.* += size;
    return value;
}

pub fn writeBytes(buf: []u8, offset: *usize, bytes: []const u8) Error!void {
    if (offset.* + bytes.len > buf.len) return error.OutputFull;
    std.mem.copyForwards(u8, buf[offset.* .. offset.* + bytes.len], bytes);
    offset.* += bytes.len;
}

pub fn readBytes(buf: []const u8, offset: *usize, len: usize) Error![]const u8 {
    if (offset.* + len > buf.len) return error.Truncated;
    const out = buf[offset.* .. offset.* + len];
    offset.* += len;
    return out;
}
