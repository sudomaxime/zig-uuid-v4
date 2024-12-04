const std = @import("std");

pub const Error = error{
    InvalidUUID,
    InvalidLength,
    InvalidFormat,
    InvalidCharacter,
    UnsupportedFormatSpecifier,
};

pub const UuidV4 = [36]u8;

pub const UUID = struct {
    /// Acts like a buffer for the stored bytes
    bytes: [16]u8,

    /// Hexadecimal characters used for formatting.
    const hex_chars = "0123456789abcdef";

    /// Generates a new Version 4 UUID.
    pub fn init() !UUID {
        var uuid = UUID{ .bytes = undefined };
        std.crypto.random.bytes(&uuid.bytes);

        // Set version to 4
        uuid.bytes[6] = (uuid.bytes[6] & 0x0F) | 0x40;

        // Set variant to RFC 4122
        uuid.bytes[8] = (uuid.bytes[8] & 0x3F) | 0x80;

        return uuid;
    }

    fn hex_char_to_val(c: u8) ?u8 {
        if (c >= '0' and c <= '9') {
            return c - '0';
        } else if (c >= 'a' and c <= 'f') {
            return c - 'a' + 10;
        } else if (c >= 'A' and c <= 'F') {
            return c - 'A' + 10;
        } else {
            return null;
        }
    }

    /// Converts the UUID to its string representation.
    pub fn to_string(self: UUID) UuidV4 {
        var buf: [36]u8 = undefined;
        var index: usize = 0;
        var byte_index: usize = 0;

        inline for (self.bytes) |byte| {
            if (byte_index == 4 or byte_index == 6 or byte_index == 8 or byte_index == 10) {
                buf[index] = '-';
                index += 1;
            }
            buf[index] = hex_chars[byte >> 4];
            buf[index + 1] = hex_chars[byte & 0x0F];
            index += 2;
            byte_index += 1;
        }

        return buf;
    }

    /// Parses a UUID string into a UUID struct.
    pub fn parse(s: []const u8) !UUID {
        if (s.len != 36)
            return error.InvalidLength;

        const hyphen_positions = [_]usize{ 8, 13, 18, 23 };
        for (hyphen_positions) |pos| {
            if (s[pos] != '-')
                return error.InvalidFormat;
        }

        var bytes: [16]u8 = undefined;
        var byte_index: usize = 0;
        var i: usize = 0;
        while (byte_index < 16) {
            if (i >= s.len)
                return error.InvalidFormat; // Reached end of string unexpectedly
            if (s[i] == '-') {
                i += 1;
                continue;
            }
            if (i + 1 >= s.len)
                return error.InvalidFormat; // Not enough characters for a full byte
            const hi = hex_char_to_val(s[i]) orelse return error.InvalidCharacter;
            const lo = hex_char_to_val(s[i + 1]) orelse return error.InvalidCharacter;
            bytes[byte_index] = ((hi << 4) | lo);
            byte_index += 1;
            i += 2;
        }

        return UUID{ .bytes = bytes };
    }

    /// Implements the fmt.Format interface for printing.
    pub fn format(
        self: UUID,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        if (fmt.len != 0 and fmt[0] != 's') {
            return error.UnsupportedFormatSpecifier;
        }
        var buf: [36]u8 = self.to_string();
        try writer.writeAll(&buf);
    }

    /// Equality comparison for UUIDs.
    pub fn equals(self: UUID, other: UUID) bool {
        return std.mem.eql(u8, self.bytes[0..], other.bytes[0..]);
    }

    /// Zero UUID constant.
    pub const zero: UUID = UUID{ .bytes = .{0} ** 16 };
};

test "Parsing valid UUID strings" {
    const uuid_strs = [_][]const u8{
        "123e4567-e89b-12d3-a456-426614174000",
        "ffffffff-ffff-4fff-8fff-ffffffffffff",
        "00000000-0000-4000-8000-000000000000",
        "a1b2c3d4-e5f6-4a1b-b2c3-d4e5f6a1b2c3",
    };

    for (uuid_strs) |uuid_str| {
        const uuid = try UUID.parse(uuid_str);
        const reconstructed_str = uuid.to_string();
        try std.testing.expectEqualStrings(uuid_str, &reconstructed_str);
    }
}

test "check to_string works" {
    const uuid = try UUID.init();
    const uuid_str = uuid.to_string();

    const parsed_uuid = try UUID.parse(&uuid_str);
    try std.testing.expect(uuid.equals(parsed_uuid));
}

test "Parsing invalid UUID strings" {
    const invalid_uuid_strs = [_][]const u8{
        "123e4567-e89b-12d3-a456-42661417400", // Too short
        "123e4567-e89b-12d3-a456-4266141740000", // Too long
        "123e4567e89b12d3a456426614174000", // Missing hyphens
        "g23e4567-e89b-12d3-a456-426614174000", // Invalid hex character 'g'
        "123e4567-e89b-12d3-a456-42661417400z", // Invalid hex character 'z'
        "123e4567-e89b-12d3-a456-42661417400-", // Trailing hyphen
        "123e4567-e89b-12d3-a456-42661417400 ", // Trailing space
        "", // Empty string
        "------------------------------------", // Only hyphens
    };

    for (invalid_uuid_strs) |uuid_str| {
        const parse_result = UUID.parse(uuid_str);

        if (parse_result) |_| {
            // Parsing succeeded when it should have failed; fail the test
            try std.testing.expect(false);
        } else |err| {
            // Parsing failed as expected; check if the error is one of the expected errors
            try std.testing.expect(err == Error.InvalidUUID or
                err == Error.InvalidLength or
                err == Error.InvalidFormat or
                err == Error.InvalidCharacter);
        }
    }
}

test "UUID uniqueness" {
    const num_uuids = 1_000;

    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();

    const allocator = &arena_allocator.allocator();

    var uuids = try allocator.alloc(UUID, num_uuids);
    defer allocator.free(uuids);

    // Generate UUIDs
    for (uuids) |*uuid| {
        uuid.* = try UUID.init();
    }

    var i: usize = 0;

    // Check for duplicates
    for (uuids) |uuid| {
        for (uuids[(i + 1)..]) |other_uuid| {
            try std.testing.expect(!uuid.equals(other_uuid));
        }
        i = i + 1;
    }
}

test "UUID equality comparison" {
    const uuid1 = try UUID.init();
    const uuid2 = try UUID.init();

    // A UUID should be equal to itself
    try std.testing.expect(uuid1.equals(uuid1));

    // Different UUIDs should not be equal
    try std.testing.expect(!uuid1.equals(uuid2));

    // Parsing a UUID string should result in an equal UUID
    const uuid_str = uuid1.to_string();
    const parsed_uuid = try UUID.parse(&uuid_str);
    try std.testing.expect(uuid1.equals(parsed_uuid));
}

test "Zero UUID" {
    const zero_uuid = UUID.zero;
    const zero_uuid_str = zero_uuid.to_string();

    // The zero UUID string should be all zeros
    try std.testing.expectEqualStrings("00000000-0000-0000-0000-000000000000", &zero_uuid_str);

    // Parsing the zero UUID string should result in the zero UUID
    const parsed_uuid = try UUID.parse(&zero_uuid_str);
    try std.testing.expect(zero_uuid.equals(parsed_uuid));
}
