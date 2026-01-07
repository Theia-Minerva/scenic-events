const events = @import("events");

pub const StreamDecl = struct {
    stream_id: u8,
    producer_namespace: []const u8,
    schema_id: u32,
    producer_version: u32,

    pub fn encodedLen(self: StreamDecl) usize {
        return 1 + 1 + self.producer_namespace.len + 4 + 4;
    }
};

pub const StreamState = extern struct {
    stream_id: u8,
    has_last_seq: u8,
    _padding: u16,
    last_seq: u32,
};

pub const StreamRegistry = struct {
    entries: []StreamState,
    count: usize,

    pub fn init(storage: []StreamState) StreamRegistry {
        return .{
            .entries = storage,
            .count = 0,
        };
    }

    pub fn isDeclared(self: *const StreamRegistry, stream_id: u8) bool {
        return self.indexOf(stream_id) != null;
    }

    pub fn add(self: *StreamRegistry, stream_id: u8) events.Error!void {
        if (self.indexOf(stream_id) != null) return error.StreamAlreadyDeclared;
        if (self.count >= self.entries.len) return error.StreamRegistryFull;
        self.entries[self.count] = .{
            .stream_id = stream_id,
            .has_last_seq = 0,
            ._padding = 0,
            .last_seq = 0,
        };
        self.count += 1;
    }

    pub fn markSequence(self: *StreamRegistry, stream_id: u8, sequence: u32) events.Error!void {
        const idx = self.indexOf(stream_id) orelse return error.StreamNotDeclared;
        const state = &self.entries[idx];
        if (state.has_last_seq != 0) {
            if (sequence <= state.last_seq) return error.SequenceNotMonotonic;
        }
        state.has_last_seq = 1;
        state.last_seq = sequence;
    }

    fn indexOf(self: *const StreamRegistry, stream_id: u8) ?usize {
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            if (self.entries[i].stream_id == stream_id) return i;
        }
        return null;
    }
};
