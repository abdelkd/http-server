const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const Connection = std.net.Server.Connection;
const File = std.fs.File;
const ArrayList = std.ArrayList;

const headers = @import("headers.zig");
const response = @import("response.zig");

pub fn route(conn: Connection, http_headers: headers.HTTPHeaders, serving_path: []const u8, allocator: mem.Allocator) headers.ServerErrors!void {
    const path = fs.path.resolve(allocator, &.{serving_path}) catch {
        //TODO: 500 Error
        return headers.ServerErrors.InternalServerError;
    };
    defer allocator.free(path);

    const routes_dir = fs.cwd().openDir(path, .{ .iterate = true }) catch {
        return headers.ServerErrors.NotFound;
    };

    if (mem.eql(u8, http_headers.path, "/")) {
        _ = routes_dir.statFile("index.html") catch return headers.ServerErrors.NotFound;

        var html_file = routes_dir.openFile("index.html", .{}) catch return headers.ServerErrors.InternalServerError;

        serveFile(conn, &html_file, allocator) catch return headers.ServerErrors.InternalServerError;
        return;
    }

    var file_path = mem.trimLeft(u8, http_headers.path, "/");
    file_path = mem.trimRight(u8, file_path, "/");

    var user_route_path = routes_dir.openDir(file_path, .{}) catch return headers.ServerErrors.NotFound;

    _ = user_route_path.statFile("index.html") catch {
        return headers.ServerErrors.NotFound;
    };

    var html_file = user_route_path.openFile("index.html", .{}) catch return headers.ServerErrors.InternalServerError;

    serveFile(conn, &html_file, allocator) catch return headers.ServerErrors.InternalServerError;
}

fn serveFile(conn: Connection, file: *File, allocator: mem.Allocator) !void {
    const buf = try file.reader().readAllAlloc(allocator, 4096 * 4);
    defer allocator.free(buf);

    var http_headers = ArrayList(headers.Header).init(allocator);
    defer http_headers.deinit();

    const options = response.ResponseOptions{
        .content_type = "text/html",
        .status_message = "OK",
        .status_code = 200,
        .buf = buf,
        .content_length = buf.len,
    };

    try response.httpResponse(conn, http_headers, options);
}
