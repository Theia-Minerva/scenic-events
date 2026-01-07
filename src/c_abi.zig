const events = @import("events");

pub const se_stream_state = events.StreamState;

pub const se_events_error = enum(c_int) {
    ok = 0,
    end_of_stream = 1,
    invalid_args = 2,
    invalid_magic = 3,
    unsupported_version = 4,
    truncated = 5,
    output_full = 6,
    unknown_record_kind = 7,
    stream_already_declared = 8,
    stream_not_declared = 9,
    stream_registry_full = 10,
    sequence_not_monotonic = 11,
    namespace_too_long = 12,
    payload_too_large = 13,
    missing_header = 14,
};

pub const se_record_kind = enum(u8) {
    stream_decl = 1,
    event = 2,
};

pub const se_stream_decl = extern struct {
    stream_id: u8,
    producer_namespace: ?[*]const u8,
    producer_namespace_len: u8,
    schema_id: u32,
    producer_version: u32,
};

pub const se_event = extern struct {
    stream_id: u8,
    sequence: u32,
    payload: ?[*]const u8,
    payload_len: u32,
};

pub const se_record_data = extern union {
    stream_decl: se_stream_decl,
    event: se_event,
};

pub const se_record = extern struct {
    kind: se_record_kind,
    data: se_record_data,
};

pub const se_writer = extern struct {
    buffer: ?[*]u8,
    buffer_len: usize,
    offset: usize,
    registry: ?[*]events.StreamState,
    registry_len: usize,
    registry_count: usize,
    wrote_header: u8,
};

pub const se_reader = extern struct {
    bytes: ?[*]const u8,
    bytes_len: usize,
    offset: usize,
    registry: ?[*]events.StreamState,
    registry_len: usize,
    registry_count: usize,
    header_version: u8,
};

fn mapError(err: events.Error) se_events_error {
    return switch (err) {
        error.InvalidMagic => .invalid_magic,
        error.UnsupportedVersion => .unsupported_version,
        error.Truncated => .truncated,
        error.OutputFull => .output_full,
        error.MissingHeader => .missing_header,
        error.UnknownRecordKind => .unknown_record_kind,
        error.StreamAlreadyDeclared => .stream_already_declared,
        error.StreamNotDeclared => .stream_not_declared,
        error.StreamRegistryFull => .stream_registry_full,
        error.SequenceNotMonotonic => .sequence_not_monotonic,
        error.NamespaceTooLong => .namespace_too_long,
        error.PayloadTooLarge => .payload_too_large,
    };
}

fn writerFrom(handle: *se_writer) events.Writer {
    const buffer = handle.buffer.?[0..handle.buffer_len];
    const registry_slice = handle.registry.?[0..handle.registry_len];
    return .{
        .buf = buffer,
        .offset = handle.offset,
        .registry = .{
            .entries = registry_slice,
            .count = handle.registry_count,
        },
        .wrote_header = handle.wrote_header != 0,
    };
}

fn syncWriter(handle: *se_writer, writer: events.Writer) void {
    handle.offset = writer.offset;
    handle.registry_count = writer.registry.count;
    handle.wrote_header = if (writer.wrote_header) 1 else 0;
}

pub export fn se_writer_init(
    writer: ?*se_writer,
    buffer: ?[*]u8,
    buffer_len: usize,
    registry: ?[*]events.StreamState,
    registry_len: usize,
) c_int {
    if (writer == null) return @intFromEnum(se_events_error.invalid_args);
    if (buffer_len > 0 and buffer == null) return @intFromEnum(se_events_error.invalid_args);
    if (registry_len > 0 and registry == null) return @intFromEnum(se_events_error.invalid_args);

    writer.?.* = .{
        .buffer = buffer,
        .buffer_len = buffer_len,
        .offset = 0,
        .registry = registry,
        .registry_len = registry_len,
        .registry_count = 0,
        .wrote_header = 0,
    };
    return @intFromEnum(se_events_error.ok);
}

pub export fn se_writer_write_header(writer: ?*se_writer) c_int {
    if (writer == null) return @intFromEnum(se_events_error.invalid_args);
    if (writer.?.buffer_len > 0 and writer.?.buffer == null) {
        return @intFromEnum(se_events_error.invalid_args);
    }
    if (writer.?.registry_len > 0 and writer.?.registry == null) {
        return @intFromEnum(se_events_error.invalid_args);
    }

    var w = writerFrom(writer.?);
    w.writeHeader() catch |err| return @intFromEnum(mapError(err));
    syncWriter(writer.?, w);
    return @intFromEnum(se_events_error.ok);
}

pub export fn se_writer_declare_stream(
    writer: ?*se_writer,
    stream_id: u8,
    producer_namespace: ?[*]const u8,
    producer_namespace_len: u8,
    schema_id: u32,
    producer_version: u32,
) c_int {
    if (writer == null) return @intFromEnum(se_events_error.invalid_args);
    if (producer_namespace_len > 0 and producer_namespace == null) {
        return @intFromEnum(se_events_error.invalid_args);
    }
    if (writer.?.buffer_len > 0 and writer.?.buffer == null) {
        return @intFromEnum(se_events_error.invalid_args);
    }
    if (writer.?.registry_len > 0 and writer.?.registry == null) {
        return @intFromEnum(se_events_error.invalid_args);
    }

    const ns = if (producer_namespace_len == 0) &[_]u8{} else producer_namespace.?[0..producer_namespace_len];
    var w = writerFrom(writer.?);
    w.declareStream(.{
        .stream_id = stream_id,
        .producer_namespace = ns,
        .schema_id = schema_id,
        .producer_version = producer_version,
    }) catch |err| return @intFromEnum(mapError(err));

    syncWriter(writer.?, w);
    return @intFromEnum(se_events_error.ok);
}

pub export fn se_writer_write_event(
    writer: ?*se_writer,
    stream_id: u8,
    sequence: u32,
    payload: ?[*]const u8,
    payload_len: u32,
) c_int {
    if (writer == null) return @intFromEnum(se_events_error.invalid_args);
    if (payload_len > 0 and payload == null) {
        return @intFromEnum(se_events_error.invalid_args);
    }
    if (writer.?.buffer_len > 0 and writer.?.buffer == null) {
        return @intFromEnum(se_events_error.invalid_args);
    }
    if (writer.?.registry_len > 0 and writer.?.registry == null) {
        return @intFromEnum(se_events_error.invalid_args);
    }

    const bytes = if (payload_len == 0) &[_]u8{} else payload.?[0..payload_len];
    var w = writerFrom(writer.?);
    w.writeEvent(.{
        .stream_id = stream_id,
        .sequence = sequence,
        .payload = bytes,
    }) catch |err| return @intFromEnum(mapError(err));

    syncWriter(writer.?, w);
    return @intFromEnum(se_events_error.ok);
}

pub export fn se_writer_bytes(writer: ?*const se_writer, out_len: ?*usize) ?[*]const u8 {
    if (writer == null) {
        if (out_len) |len_ptr| len_ptr.* = 0;
        return null;
    }

    const handle = writer.?;
    if (handle.buffer_len > 0 and handle.buffer == null) {
        if (out_len) |len_ptr| len_ptr.* = 0;
        return null;
    }

    if (out_len) |len_ptr| len_ptr.* = handle.offset;
    if (handle.offset == 0) return null;
    return handle.buffer.?;
}

pub export fn se_reader_init(
    reader: ?*se_reader,
    bytes: ?[*]const u8,
    bytes_len: usize,
    registry: ?[*]events.StreamState,
    registry_len: usize,
) c_int {
    if (reader == null) return @intFromEnum(se_events_error.invalid_args);
    if (bytes_len > 0 and bytes == null) return @intFromEnum(se_events_error.invalid_args);
    if (registry_len > 0 and registry == null) return @intFromEnum(se_events_error.invalid_args);

    reader.?.* = .{
        .bytes = bytes,
        .bytes_len = bytes_len,
        .offset = 0,
        .registry = registry,
        .registry_len = registry_len,
        .registry_count = 0,
        .header_version = 0,
    };

    const slice = if (bytes_len == 0) &[_]u8{} else bytes.?[0..bytes_len];
    const registry_slice = if (registry_len == 0)
        @constCast(&[_]events.StreamState{})
    else
        registry.?[0..registry_len];
    var reg = events.StreamRegistry.init(registry_slice);
    const r = events.Reader.init(slice, &reg) catch |err| return @intFromEnum(mapError(err));

    reader.?.offset = r.offset;
    reader.?.registry_count = reg.count;
    reader.?.header_version = r.header.version;

    return @intFromEnum(se_events_error.ok);
}

pub export fn se_reader_header_version(reader: ?*const se_reader) u8 {
    if (reader == null) return 0;
    return reader.?.header_version;
}

pub export fn se_reader_next(reader: ?*se_reader, out_record: ?*se_record) c_int {
    if (reader == null or out_record == null) return @intFromEnum(se_events_error.invalid_args);
    if (reader.?.bytes_len > 0 and reader.?.bytes == null) {
        return @intFromEnum(se_events_error.invalid_args);
    }
    if (reader.?.registry_len > 0 and reader.?.registry == null) {
        return @intFromEnum(se_events_error.invalid_args);
    }

    const bytes = if (reader.?.bytes_len == 0) &[_]u8{} else reader.?.bytes.?[0..reader.?.bytes_len];
    const registry_slice = if (reader.?.registry_len == 0)
        @constCast(&[_]events.StreamState{})
    else
        reader.?.registry.?[0..reader.?.registry_len];
    var registry = events.StreamRegistry{
        .entries = registry_slice,
        .count = reader.?.registry_count,
    };
    var r = events.Reader{
        .bytes = bytes,
        .offset = reader.?.offset,
        .registry = &registry,
        .header = .{ .version = reader.?.header_version },
    };

    const next_record = r.next() catch |err| return @intFromEnum(mapError(err));
    if (next_record == null) {
        reader.?.offset = r.offset;
        reader.?.registry_count = registry.count;
        return @intFromEnum(se_events_error.end_of_stream);
    }

    const record = next_record.?;
    switch (record) {
        .stream_decl => |decl| {
            out_record.?.* = .{
                .kind = .stream_decl,
                .data = .{ .stream_decl = .{
                    .stream_id = decl.stream_id,
                    .producer_namespace = if (decl.producer_namespace.len == 0) null else decl.producer_namespace.ptr,
                    .producer_namespace_len = @as(u8, @intCast(decl.producer_namespace.len)),
                    .schema_id = decl.schema_id,
                    .producer_version = decl.producer_version,
                } },
            };
        },
        .event => |event| {
            out_record.?.* = .{
                .kind = .event,
                .data = .{ .event = .{
                    .stream_id = event.stream_id,
                    .sequence = event.sequence,
                    .payload = if (event.payload.len == 0) null else event.payload.ptr,
                    .payload_len = @as(u32, @intCast(event.payload.len)),
                } },
            };
        },
    }

    reader.?.offset = r.offset;
    reader.?.registry_count = registry.count;
    return @intFromEnum(se_events_error.ok);
}
