const std = @import("std");
const events = @import("events");

test "container roundtrip" {
    var buf: [256]u8 = undefined;
    var registry_storage: [4]events.StreamState = undefined;
    var writer = events.Writer.init(&buf, &registry_storage);

    try writer.writeHeader();

    try writer.declareStream(.{
        .stream_id = 1,
        .producer_namespace = "scenic.kernel",
        .schema_id = 1001,
        .producer_version = 1,
    });

    try writer.writeEvent(.{
        .stream_id = 1,
        .sequence = 1,
        .payload = "\x01\x02",
    });

    try writer.declareStream(.{
        .stream_id = 2,
        .producer_namespace = "scenic.host",
        .schema_id = 2001,
        .producer_version = 3,
    });

    try writer.writeEvent(.{
        .stream_id = 2,
        .sequence = 7,
        .payload = "\xAA\xBB\xCC",
    });

    const bytes = writer.bytes();

    var read_storage: [4]events.StreamState = undefined;
    var registry = events.StreamRegistry.init(&read_storage);
    var reader = try events.Reader.init(bytes, &registry);

    try std.testing.expectEqual(events.current_version, reader.header.version);

    const first = (try reader.next()).?;
    switch (first) {
        .stream_decl => |decl| {
            try std.testing.expectEqual(@as(u8, 1), decl.stream_id);
            try std.testing.expectEqual(@as(u32, 1001), decl.schema_id);
            try std.testing.expectEqual(@as(u32, 1), decl.producer_version);
            try std.testing.expect(std.mem.eql(u8, decl.producer_namespace, "scenic.kernel"));
        },
        else => try std.testing.expect(false),
    }

    const second = (try reader.next()).?;
    switch (second) {
        .event => |event| {
            try std.testing.expectEqual(@as(u8, 1), event.stream_id);
            try std.testing.expectEqual(@as(u32, 1), event.sequence);
            try std.testing.expect(std.mem.eql(u8, event.payload, "\x01\x02"));
        },
        else => try std.testing.expect(false),
    }

    const third = (try reader.next()).?;
    switch (third) {
        .stream_decl => |decl| {
            try std.testing.expectEqual(@as(u8, 2), decl.stream_id);
            try std.testing.expectEqual(@as(u32, 2001), decl.schema_id);
            try std.testing.expectEqual(@as(u32, 3), decl.producer_version);
            try std.testing.expect(std.mem.eql(u8, decl.producer_namespace, "scenic.host"));
        },
        else => try std.testing.expect(false),
    }

    const fourth = (try reader.next()).?;
    switch (fourth) {
        .event => |event| {
            try std.testing.expectEqual(@as(u8, 2), event.stream_id);
            try std.testing.expectEqual(@as(u32, 7), event.sequence);
            try std.testing.expect(std.mem.eql(u8, event.payload, "\xAA\xBB\xCC"));
        },
        else => try std.testing.expect(false),
    }

    try std.testing.expect((try reader.next()) == null);
}
