const std = @import("std");
const events = @import("events");

pub const magic = [_]u8{ 'S', 'C', 'E', 'V' };
pub const current_version: u8 = 1;

pub const Header = struct {
    version: u8,

    pub fn encodedLen() usize {
        return magic.len + 1;
    }

    pub fn write(self: Header, buf: []u8, offset: *usize) events.Error!void {
        try events.writeBytes(buf, offset, &magic);
        try events.writeIntLittle(u8, buf, offset, self.version);
    }

    pub fn read(buf: []const u8, offset: *usize) events.Error!Header {
        const header_magic = try events.readBytes(buf, offset, magic.len);
        if (!std.mem.eql(u8, header_magic, &magic)) return error.InvalidMagic;
        const version = try events.readIntLittle(u8, buf, offset);
        if (version != current_version) return error.UnsupportedVersion;
        return .{ .version = version };
    }
};
