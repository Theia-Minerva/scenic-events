const std = @import("std");
const events = @import("events");

fn writeHeader(buf: []u8, offset: *usize) !void {
    const hdr = events.Header{ .version = events.current_version };
    try hdr.write(buf, offset);
}

fn writeStreamDecl(
    buf: []u8,
    offset: *usize,
    stream_id: u8,
    namespace: []const u8,
    schema_id: u32,
    producer_version: u32,
) !void {
    try events.writeIntLittle(u8, buf, offset, @intFromEnum(events.RecordKind.stream_decl));
    try events.writeIntLittle(u8, buf, offset, stream_id);
    try events.writeIntLittle(u8, buf, offset, @as(u8, @intCast(namespace.len)));
    try events.writeBytes(buf, offset, namespace);
    try events.writeIntLittle(u32, buf, offset, schema_id);
    try events.writeIntLittle(u32, buf, offset, producer_version);
}

fn writeEvent(buf: []u8, offset: *usize, stream_id: u8, seq: u32, payload: []const u8) !void {
    try events.writeIntLittle(u8, buf, offset, @intFromEnum(events.RecordKind.event));
    try events.writeIntLittle(u8, buf, offset, stream_id);
    try events.writeIntLittle(u32, buf, offset, seq);
    try events.writeIntLittle(u32, buf, offset, @as(u32, @intCast(payload.len)));
    try events.writeBytes(buf, offset, payload);
}

test "unknown stream rejection" {
    var buf: [64]u8 = undefined;
    var offset: usize = 0;

    try writeHeader(&buf, &offset);
    try writeEvent(&buf, &offset, 9, 1, "\x00");

    var storage: [2]events.StreamState = undefined;
    var registry = events.StreamRegistry.init(&storage);
    var reader = try events.Reader.init(buf[0..offset], &registry);

    try std.testing.expectError(error.StreamNotDeclared, reader.next());
}

test "events before declaration rejected" {
    var buf: [128]u8 = undefined;
    var offset: usize = 0;

    try writeHeader(&buf, &offset);
    try writeEvent(&buf, &offset, 1, 1, "\xAB\xCD");
    try writeStreamDecl(&buf, &offset, 1, "late", 4, 1);

    var storage: [2]events.StreamState = undefined;
    var registry = events.StreamRegistry.init(&storage);
    var reader = try events.Reader.init(buf[0..offset], &registry);

    try std.testing.expectError(error.StreamNotDeclared, reader.next());
}

test "stream redeclaration rejected" {
    var buf: [128]u8 = undefined;
    var offset: usize = 0;

    try writeHeader(&buf, &offset);
    try writeStreamDecl(&buf, &offset, 3, "alpha", 10, 1);
    try writeStreamDecl(&buf, &offset, 3, "alpha", 10, 1);

    var storage: [2]events.StreamState = undefined;
    var registry = events.StreamRegistry.init(&storage);
    var reader = try events.Reader.init(buf[0..offset], &registry);

    _ = (try reader.next()).?;
    try std.testing.expectError(error.StreamAlreadyDeclared, reader.next());
}

test "deterministic ordering preserved" {
    var buf: [256]u8 = undefined;
    var storage: [4]events.StreamState = undefined;
    var writer = events.Writer.init(&buf, &storage);

    try writer.writeHeader();
    try writer.declareStream(.{
        .stream_id = 1,
        .producer_namespace = "ns.one",
        .schema_id = 1,
        .producer_version = 1,
    });
    try writer.declareStream(.{
        .stream_id = 2,
        .producer_namespace = "ns.two",
        .schema_id = 2,
        .producer_version = 1,
    });
    try writer.writeEvent(.{
        .stream_id = 1,
        .sequence = 1,
        .payload = "\x01",
    });
    try writer.writeEvent(.{
        .stream_id = 2,
        .sequence = 1,
        .payload = "\x02",
    });

    var read_storage: [4]events.StreamState = undefined;
    var registry = events.StreamRegistry.init(&read_storage);
    var reader = try events.Reader.init(writer.bytes(), &registry);

    const first = (try reader.next()).?;
    const second = (try reader.next()).?;
    const third = (try reader.next()).?;
    const fourth = (try reader.next()).?;

    try std.testing.expect(std.meta.activeTag(first) == .stream_decl);
    try std.testing.expect(std.meta.activeTag(second) == .stream_decl);
    try std.testing.expect(std.meta.activeTag(third) == .event);
    try std.testing.expect(std.meta.activeTag(fourth) == .event);
}

test "sequence monotonicity enforced" {
    var buf: [128]u8 = undefined;
    var offset: usize = 0;

    try writeHeader(&buf, &offset);
    try writeStreamDecl(&buf, &offset, 5, "seq", 1, 1);
    try writeEvent(&buf, &offset, 5, 2, "\x01");
    try writeEvent(&buf, &offset, 5, 1, "\x02");

    var storage: [2]events.StreamState = undefined;
    var registry = events.StreamRegistry.init(&storage);
    var reader = try events.Reader.init(buf[0..offset], &registry);

    _ = (try reader.next()).?;
    _ = (try reader.next()).?;
    try std.testing.expectError(error.SequenceNotMonotonic, reader.next());
}
