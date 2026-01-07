const std = @import("std");
const events = @import("events");

pub const Writer = struct {
    buf: []u8,
    offset: usize,
    registry: events.StreamRegistry,
    wrote_header: bool,

    pub fn init(buf: []u8, registry_storage: []events.StreamState) Writer {
        return .{
            .buf = buf,
            .offset = 0,
            .registry = events.StreamRegistry.init(registry_storage),
            .wrote_header = false,
        };
    }

    pub fn writeHeader(self: *Writer) events.Error!void {
        if (self.wrote_header) return;
        const hdr = events.Header{ .version = events.current_version };
        try hdr.write(self.buf, &self.offset);
        self.wrote_header = true;
    }

    pub fn declareStream(self: *Writer, decl: events.StreamDecl) events.Error!void {
        if (!self.wrote_header) return error.MissingHeader;
        if (decl.producer_namespace.len > std.math.maxInt(u8)) return error.NamespaceTooLong;
        try self.registry.add(decl.stream_id);
        try events.writeIntLittle(u8, self.buf, &self.offset, @intFromEnum(events.RecordKind.stream_decl));
        try events.writeIntLittle(u8, self.buf, &self.offset, decl.stream_id);
        try events.writeIntLittle(u8, self.buf, &self.offset, @as(u8, @intCast(decl.producer_namespace.len)));
        try events.writeBytes(self.buf, &self.offset, decl.producer_namespace);
        try events.writeIntLittle(u32, self.buf, &self.offset, decl.schema_id);
        try events.writeIntLittle(u32, self.buf, &self.offset, decl.producer_version);
    }

    pub fn writeEvent(self: *Writer, event: events.EventRecord) events.Error!void {
        if (!self.wrote_header) return error.MissingHeader;
        if (event.payload.len > std.math.maxInt(u32)) return error.PayloadTooLarge;
        if (!self.registry.isDeclared(event.stream_id)) return error.StreamNotDeclared;
        try self.registry.markSequence(event.stream_id, event.sequence);
        try events.writeIntLittle(u8, self.buf, &self.offset, @intFromEnum(events.RecordKind.event));
        try events.writeIntLittle(u8, self.buf, &self.offset, event.stream_id);
        try events.writeIntLittle(u32, self.buf, &self.offset, event.sequence);
        try events.writeIntLittle(u32, self.buf, &self.offset, @as(u32, @intCast(event.payload.len)));
        try events.writeBytes(self.buf, &self.offset, event.payload);
    }

    pub fn bytes(self: *const Writer) []const u8 {
        return self.buf[0..self.offset];
    }
};
