const std = @import("std");
const events = @import("events");

pub const Reader = struct {
    bytes: []const u8,
    offset: usize,
    registry: *events.StreamRegistry,
    header: events.Header,

    pub fn init(bytes: []const u8, registry: *events.StreamRegistry) events.Error!Reader {
        std.debug.assert(registry.count == 0);
        var offset: usize = 0;
        const hdr = try events.Header.read(bytes, &offset);
        return .{
            .bytes = bytes,
            .offset = offset,
            .registry = registry,
            .header = hdr,
        };
    }

    pub fn next(self: *Reader) events.Error!?events.Record {
        if (self.offset >= self.bytes.len) return null;
        const kind_u8 = try events.readIntLittle(u8, self.bytes, &self.offset);
        const kind = std.meta.intToEnum(events.RecordKind, kind_u8) catch return error.UnknownRecordKind;

        switch (kind) {
            .stream_decl => {
                const stream_id = try events.readIntLittle(u8, self.bytes, &self.offset);
                const ns_len = try events.readIntLittle(u8, self.bytes, &self.offset);
                const ns_bytes = try events.readBytes(self.bytes, &self.offset, ns_len);
                const schema_id = try events.readIntLittle(u32, self.bytes, &self.offset);
                const producer_version = try events.readIntLittle(u32, self.bytes, &self.offset);

                try self.registry.add(stream_id);

                return events.Record{ .stream_decl = .{
                    .stream_id = stream_id,
                    .producer_namespace = ns_bytes,
                    .schema_id = schema_id,
                    .producer_version = producer_version,
                } };
            },
            .event => {
                const stream_id = try events.readIntLittle(u8, self.bytes, &self.offset);
                const sequence = try events.readIntLittle(u32, self.bytes, &self.offset);
                const payload_len = try events.readIntLittle(u32, self.bytes, &self.offset);
                const payload = try events.readBytes(self.bytes, &self.offset, payload_len);

                try self.registry.markSequence(stream_id, sequence);

                return events.Record{ .event = .{
                    .stream_id = stream_id,
                    .sequence = sequence,
                    .payload = payload,
                } };
            },
        }
    }
};
