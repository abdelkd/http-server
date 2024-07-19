const std = @import("std");
const Connection = std.net.Server.Connection;
const ArrayList = std.ArrayList;

const headers = @import("headers.zig");

pub const ResponseOptions = struct {
    status_code: u8,
    status_message: []const u8,
    content_type: []const u8,
    buf: ?[]u8,
    content_length: usize,
};

pub fn http404(conn: Connection) !void {
    // const response = "HTTP/1.1 404 NOT FOUND\r\n" ++ "Content-Type: text/plain\r\n" ++ "Content-Length: 10\r\n\r\n" ++ "NOT FOUND\n";
    const conn_writer = conn.stream.writer();

    _ = try std.fmt.format(conn_writer, "HTTP/1.1 404 NOT FOUND\r\n", .{});
    _ = try std.fmt.format(conn_writer, "Content-Type: text/plain\r\n", .{});
    _ = try std.fmt.format(conn_writer, "Content-Length: 10\r\n", .{});
}

pub fn httpResponse(conn: Connection, http_headers: ?ArrayList(headers.Header), options: ResponseOptions) !void {
    var conn_writer = conn.stream.writer();
    _ = try std.fmt.format(conn_writer, "HTTP/1.1 {} {s}\r\n", .{ options.status_code, options.status_message });
    _ = try std.fmt.format(conn_writer, "Content-Type: {s}\r\n", .{options.content_type});
    _ = try std.fmt.format(conn_writer, "Content-Length: {}\r\n", .{options.content_length});
    _ = try std.fmt.format(conn_writer, "Cache-Control: max-age=0, must-revalidate\r\n", .{});

    if (http_headers) |reponse_headers| {
        for (reponse_headers.items) |header| {
            _ = try std.fmt.format(conn_writer, "{s}: {s}\r\n", .{ header.name, header.value });
        }
    }

    _ = try conn_writer.write("\r\n");

    if (options.buf) |content| {
        _ = try conn_writer.write(content);
    }
}
